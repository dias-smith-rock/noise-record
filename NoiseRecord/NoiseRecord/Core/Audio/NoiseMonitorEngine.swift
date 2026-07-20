import Accelerate
import AVFoundation
import Foundation

enum DeferredSessionSaveGate {
    case saveImmediately
    case requiresPaywall
    case nothingToSave
}

@Observable
@MainActor
final class NoiseMonitorEngine {
    var isMonitoring = false
    var permissionGranted = false
    var errorMessage: String?

    var currentDB: Float = 0
    var lastDBFS: Float = 0
    var maxDB: Float = 0
    var minDB: Float = 0
    var averageDB: Float = 0
    var leq: Float = 0
    var weightingType: WeightingType = DeviceCalibrationStore.weightingType
    var history: [Float] = []
    var recordingState: RecordingState = .idle
    var latestSpectrum: FFTSpectrum?
    var latestNoiseLabel: String?
    var latestNoiseConfidence: Double = 0

    /// When enabled, bypasses A/C weighting and measures raw PCM (Z-weighting).
    var isHighSensitivityMode: Bool = DeviceCalibrationStore.isHighSensitivityMode {
        didSet {
            guard oldValue != isHighSensitivityMode else { return }
            DeviceCalibrationStore.isHighSensitivityMode = isHighSensitivityMode
            AppTelemetry.logProductEvent(
                "mode_changed",
                parameters: [
                    "mode": isHighSensitivityMode ? "high_sensitivity" : "standard",
                ]
            )
            ModeSwitchPerformance.noteEngineModeChange(
                fromHighSensitivity: oldValue,
                toHighSensitivity: isHighSensitivityMode,
                isMonitoring: isMonitoring
            )
            if isMonitoring {
                restartPipeline()
            } else {
                ModeSwitchPerformance.mark(.restartPipelineSkippedNotMonitoring)
            }
            ModeSwitchPerformance.finishEngineModeChange()
            ModeSwitchPerformance.schedulePostRenderMark()
        }
    }

    var highThreshold: Float = 55 {
        didSet {
            guard !isNormalizingThresholds else { return }
            applyNormalizedThresholds(adjustingHigh: true)
        }
    }
    var lowThreshold: Float = 48 {
        didSet {
            guard !isNormalizingThresholds else { return }
            applyNormalizedThresholds(adjustingHigh: false)
        }
    }
    var voiceActivatedEnabled = false {
        didSet {
            guard !isLoadingPersistedSettings else { return }
            voiceRecorder.voiceActivatedEnabled = voiceActivatedEnabled
        }
    }
    var backgroundMonitoringEnabled = false {
        didSet {
            guard backgroundMonitoringEnabled != oldValue else { return }
            persistSettings()
            if isMonitoring {
                try? reconfigureAudioSessionForCurrentState()
            }
        }
    }
    var aiClassificationEnabled = false {
        didSet {
            guard !isLoadingPersistedSettings else { return }
            if aiClassificationEnabled, !SubscriptionManager.shared.isPremiumUser {
                aiClassificationEnabled = false
                PaywallPresenter.shared.present(context: .aiFilter)
            }
        }
    }
    var aiFilterLabels: Set<String> = [] {
        didSet {
            guard !isLoadingPersistedSettings else { return }
            persistSettings()
        }
    }
    var aiClassificationErrorMessage: String?
    var showMicrophonePermissionDenied = false

    var evidenceLatitude: Double? { locationProvider.latitude }
    var evidenceLongitude: Double? { locationProvider.longitude }

    /// Overnight sleep noise-floor monitoring profile.
    var isSleepModeActive = false
    var sleepSessionID: UUID?
    var onSleepSampleDue: (() -> Void)?
    var onSleepAnomalyClipFinished: ((RecordingFinishedEvent) -> Void)?
    var onSleepMetricsRefresh: ((Float, Float, Float) -> Void)?

    private var audioEngine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.noiseapp.processing", qos: .userInteractive)
    private var weightingFilter: AudioWeightingFilter?
    private var fftAnalyzer: FFTAnalyzer?
    private var leqCalculator = LeqCalculator()
    private var slidingAverage = SlidingAverage(windowSize: 8)
    private var sessionSumDB: Float = 0
    private var filteredScratch: [Float] = []
    private var historyBuffer = FloatTimeSeriesBuffer(capacity: 300)
    private var fftSampleRing = FFTSampleRing(capacity: FFTConfiguration.advanced.fftSize)
    private var fftScratch = [Float](repeating: 0, count: FFTConfiguration.advanced.fftSize)
    /// 频谱峰值状态仅在 processingQueue 上更新；与 MainActor 配置路径通过锁隔离。
    private let spectrumPeakTracker = SpectrumPeakTracker(
        binCount: FFTConfiguration.advanced.binCount
    )
    private var uiFrameCounter = 0
    private let voiceRecorder = VoiceActivatedRecorder()
    private let locationProvider = LocationEvidenceProvider()
    private var noiseClassifier: NoiseClassifierManager?
    private var sampleCount = 0
    private var lastUIUpdate = Date.distantPast
    private var cachedCalibrationOffset = DeviceCalibrationStore.totalOffset
    private var uiPublishGeneration: UInt64 = 0
    private var classifierBufferSkipCounter = 0
    /// Sentinel used only while a monitoring session is active.
    private var sessionMinDB: Float = 120
    /// When true, high-sensitivity was enabled only for video evidence and should be restored afterward.
    private var shouldRestoreStandardModeAfterVideo = false
    private var isApplyingTemporaryVideoHighSensitivity = false

    private struct UIPublishSnapshot: Sendable {
        let generation: UInt64
        let lastDBFS: Float
        let currentDB: Float
        let maxDB: Float
        let minDB: Float
        let averageDB: Float
        let leq: Float
        let recordingState: RecordingState
        let spectrum: FFTSpectrum?
        let history: [Float]
    }

    private enum Performance {
        /// UI refresh rate — 15 Hz is smooth for dB meters while cutting main-thread work ~3× vs 50 Hz.
        static let uiInterval: TimeInterval = 1.0 / 15.0
        /// Spectrum FFT refresh: every UI frame (~15 Hz).
        static let spectrumEveryNthUIFrame = 1
        /// 峰值保持指数衰减系数（每 UI 帧乘一次，约 15 Hz）。
        static let peakDecayFactor: Float = 0.985
    }
    private var cachedNoiseLabel: String?
    private var isNormalizingThresholds = false
    private var isLoadingPersistedSettings = false
    private var interruptionObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?
    private var calibrationObserver: NSObjectProtocol?
    private var lastSleepSampleTime = Date.distantPast
    private var lastSleepLiveActivityTime = Date.distantPast
    private var isAppInBackground = false

    private(set) var pendingSessionStopSummary: SessionStopSummary?
    private(set) var sessionStopPromptID: UUID?
    private(set) var sessionAutoSaveGateID: UUID?
    private var deferredSessionRecording: RecordingFinishedEvent?
    private var isAwaitingStopSaveDecision = false
    private var isProcessingMonitoringStop = false
    private(set) var currentMonitoringSegmentSaveCount = 0

    var onRecordingFinished: ((RecordingFinishedEvent) -> Void)?
    var onVideoEmergencyFinalize: (() -> Void)?

    /// 监测期间连续录音实时状态。
    var activeVoiceCaptureState: RecordingState {
        voiceRecorder.state
    }

    /// 监测期间连续录音链路是否运行。
    var isVoiceRecordingRunning: Bool {
        isMonitoring
    }

    /// 是否将当前帧送入声控分段录音（AI 标签过滤）；连续整段录音不受此门控。
    private var shouldProcessVoiceRecorder: Bool {
        if aiClassificationEnabled && !aiFilterLabels.isEmpty {
            return cachedNoiseLabel.map { aiFilterLabels.contains($0) } ?? false
        }
        return true
    }

    /// Effective weighting applied to the audio pipeline.
    var effectiveWeighting: WeightingType {
        isHighSensitivityMode ? .z : weightingType
    }

    func refreshCalibrationOffset() {
        cachedCalibrationOffset = DeviceCalibrationStore.totalOffset
    }

    init() {
        isLoadingPersistedSettings = true
        isNormalizingThresholds = true

        let pair = VoiceThresholdValidator.normalized(
            high: VoiceSettingsStore.highThreshold,
            low: VoiceSettingsStore.lowThreshold
        )
        highThreshold = pair.high
        lowThreshold = pair.low
        voiceActivatedEnabled = VoiceSettingsStore.voiceActivatedEnabled
        backgroundMonitoringEnabled = VoiceSettingsStore.backgroundMonitoringEnabled
        aiClassificationEnabled = VoiceSettingsStore.aiClassificationEnabled
        aiFilterLabels = VoiceSettingsStore.aiFilterLabels
        isHighSensitivityMode = DeviceCalibrationStore.isHighSensitivityMode

        voiceRecorder.highThreshold = pair.high
        voiceRecorder.lowThreshold = pair.low
        voiceRecorder.voiceActivatedEnabled = voiceActivatedEnabled
        voiceRecorder.locationSnapshot = { [weak self] in
            guard let self else { return (nil, nil) }
            return (self.locationProvider.latitude, self.locationProvider.longitude)
        }

        isNormalizingThresholds = false
        isLoadingPersistedSettings = false
        enforcePremiumFeatureAccessSilently()
        configureVoiceRecordingLimits()

        voiceRecorder.onRecordingFinished = { [weak self] event in
            Task { @MainActor in
                self?.handleRecordingFinished(event)
            }
        }

        installAudioSessionObservers()
        installCalibrationObserver()
        installSubscriptionObserver()
    }

    private func configureVoiceRecordingLimits() {
        voiceRecorder.maxClipDuration = VoiceActivatedRecorder.maxSessionDurationPro
        voiceRecorder.onClipDurationLimitReached = nil
    }

    private func installSubscriptionObserver() {
        NotificationCenter.default.addObserver(
            forName: SubscriptionManager.entitlementsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureVoiceRecordingLimits()
            self?.enforcePremiumFeatureAccessSilently()
        }
    }

    private func installCalibrationObserver() {
        calibrationObserver = NotificationCenter.default.addObserver(
            forName: DeviceCalibrationStore.didChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCalibrationOffset()
            }
        }
    }

    func requestPermissionAndStart() async {
        permissionGranted = await AudioSessionManager.requestPermission()
        guard permissionGranted else {
            setUserError(
                AudioSessionError.permissionDenied.localizedDescription,
                context: "mic_permission_denied"
            )
            showMicrophonePermissionDenied = true
            AppTelemetry.logProductEvent("permission_denied", parameters: ["type": "microphone"])
            return
        }
        showMicrophonePermissionDenied = false
        startMonitoring()
    }

    /// Ensures high-sensitivity monitoring is running for video evidence overlay.
    @discardableResult
    func ensureMonitoringForVideoEvidence() async -> Bool {
        if !permissionGranted {
            permissionGranted = await AudioSessionManager.requestPermission()
            guard permissionGranted else {
                setUserError(
                    AudioSessionError.permissionDenied.localizedDescription,
                    context: "video_mic_permission_denied"
                )
                return false
            }
        }

        let wasStandardMode = !isHighSensitivityMode
        if wasStandardMode {
            shouldRestoreStandardModeAfterVideo = true
            isApplyingTemporaryVideoHighSensitivity = true
            isHighSensitivityMode = true
            isApplyingTemporaryVideoHighSensitivity = false
        } else {
            shouldRestoreStandardModeAfterVideo = false
        }

        if !isMonitoring {
            startMonitoring()
        }

        guard isMonitoring else {
            endTemporaryHighSensitivityForVideoIfNeeded()
            return false
        }

        return true
    }

    /// Restores standard measurement mode after a temporary high-sensitivity video session.
    func endTemporaryHighSensitivityForVideoIfNeeded() {
        guard shouldRestoreStandardModeAfterVideo else { return }
        shouldRestoreStandardModeAfterVideo = false
        isHighSensitivityMode = false
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        errorMessage = nil

        safeRemoveInputTap()
        drainProcessingQueue()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        audioEngine = AVAudioEngine()

        do {
            try BackgroundAudioSession.forceActivateMeasurementAfterExternalInterruption(
                backgroundEnabled: backgroundMonitoringEnabled
            )
        } catch {
            setUserError(AudioSessionError.wrap(error).localizedDescription, context: "audio_session_config")
            return
        }

        resetStatistics()
        refreshCalibrationOffset()
        configureVoiceRecordingLimits()
        do {
            try setupAudioPipeline()
        } catch {
            teardownFailedEngineStart()
            setUserError(AudioSessionError.wrap(error).localizedDescription, context: "audio_pipeline_setup")
            return
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isMonitoring = true
            currentMonitoringSegmentSaveCount = 0
            voiceRecorder.beginSession()
            locationProvider.requestPermission()
            locationProvider.startUpdating()
            AppTelemetry.setMonitoringActive(true)
            Task {
                await LiveActivityManager.shared.startLiveActivity(
                    measurementModeName: LiveActivityContentBuilder.measurementModeName(
                        isHighSensitivity: isHighSensitivityMode
                    ),
                    weightingBadge: LiveActivityContentBuilder.initialWeightingBadge(
                        isHighSensitivity: isHighSensitivityMode
                    ),
                    isHighSensitivityMode: isHighSensitivityMode
                )
            }
        } catch {
            teardownFailedEngineStart()
            setUserError(L10n.errorEngineStartFailed(error.localizedDescription), context: "engine_start")
        }
    }

    func requestMonitoringStopWithSavePrompt() {
        stopMonitoring(presentSessionSavePrompt: true)
    }

    /// 新手任务：满 10 秒时导出当前监测录音到 Files，并继续监测。
    func exportOnboardingMonitoringSnapshot() {
        guard isMonitoring, !isSleepModeActive else { return }
        guard !AppOnboardingStore.hasSavedMeasureReport else { return }

        let events = voiceRecorder.endSession(
            peakDB: maxDB,
            averageDB: averageDB,
            noiseType: latestNoiseLabel,
            latitude: locationProvider.latitude,
            longitude: locationProvider.longitude
        )

        var didSaveSessionReport = false
        for event in events where event.isSessionRecording {
            onRecordingFinished?(event)
            didSaveSessionReport = true
        }

        guard didSaveSessionReport else {
            voiceRecorder.beginSession()
            return
        }

        AppOnboardingStore.markMeasureReportSaved()
        AppTelemetry.logProductEvent("onboarding_measure_report_saved")
        voiceRecorder.beginSession()
    }

    func stopMonitoring(presentSessionSavePrompt: Bool = true) {
        guard isMonitoring else { return }
        if presentSessionSavePrompt {
            prepareStopWithSavePrompt()
        }
        isProcessingMonitoringStop = true
        defer { isProcessingMonitoringStop = false }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        locationProvider.stopUpdating()
        let finishedEvents = voiceRecorder.endSession(
            peakDB: maxDB,
            averageDB: averageDB,
            noiseType: latestNoiseLabel,
            latitude: locationProvider.latitude,
            longitude: locationProvider.longitude
        )
        for event in finishedEvents {
            handleRecordingFinished(event)
        }
        noiseClassifier?.stop()
        isMonitoring = false
        recordingState = .idle
        minDB = 0
        sessionMinDB = 120
        AppTelemetry.setMonitoringActive(false)
        AppTelemetry.logProductEvent("monitoring_stop")
        Task {
            await LiveActivityManager.shared.endLiveActivity()
        }
        if presentSessionSavePrompt {
            buildPendingSessionStopSummaryIfNeeded()
        } else {
            queueInternalSessionSaveGateIfNeeded()
        }
    }

    func prepareStopWithSavePrompt() {
        isAwaitingStopSaveDecision = true
        deferredSessionRecording = nil
        pendingSessionStopSummary = nil
        sessionStopPromptID = nil
    }

    func buildPendingSessionStopSummaryIfNeeded() {
        isAwaitingStopSaveDecision = false
        guard let event = deferredSessionRecording else {
            clearStopSavePromptState()
            return
        }

        let fileName = event.fileURL.lastPathComponent
        let startedAt = RecordingSession.parseStartDate(from: fileName) ?? event.startedAt
        let fileSize = Int64(
            (try? event.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        )
        pendingSessionStopSummary = SessionStopSummary(
            duration: max(0, event.endedAt.timeIntervalSince(startedAt)),
            fileSizeBytes: fileSize,
            autoSavedSegmentCount: currentMonitoringSegmentSaveCount,
            deferredEvent: event
        )
        sessionStopPromptID = UUID()
    }

    func deferredSessionSaveGate() -> DeferredSessionSaveGate {
        guard let event = deferredSessionRecording else { return .nothingToSave }
        if SubscriptionManager.shared.isPremiumUser { return .saveImmediately }
        let fileName = event.fileURL.lastPathComponent
        let startedAt = RecordingSession.parseStartDate(from: fileName) ?? event.startedAt
        let duration = max(0, event.endedAt.timeIntervalSince(startedAt))
        if duration > VoiceActivatedRecorder.freeMaxClipDuration {
            return .requiresPaywall
        }
        return .saveImmediately
    }

    func commitDeferredSessionRecording() {
        guard let event = deferredSessionRecording else {
            clearStopSavePromptState()
            return
        }
        deferredSessionRecording = nil
        pendingSessionStopSummary = nil
        sessionStopPromptID = nil
        sessionAutoSaveGateID = nil
        isAwaitingStopSaveDecision = false
        currentMonitoringSegmentSaveCount = 0
        onRecordingFinished?(event)
    }

    func discardDeferredSessionRecording() {
        guard let event = deferredSessionRecording else {
            clearStopSavePromptState()
            return
        }
        try? FileManager.default.removeItem(at: event.fileURL)
        VideoNoiseTimelineStore.remove(for: event.fileURL)
        clearStopSavePromptState()
    }

    func clearStopSavePromptState() {
        deferredSessionRecording = nil
        pendingSessionStopSummary = nil
        sessionStopPromptID = nil
        sessionAutoSaveGateID = nil
        isAwaitingStopSaveDecision = false
        currentMonitoringSegmentSaveCount = 0
    }

    private func queueInternalSessionSaveGateIfNeeded() {
        guard deferredSessionRecording != nil else {
            clearStopSavePromptState()
            return
        }
        sessionAutoSaveGateID = UUID()
    }

    private func handleRecordingFinished(_ event: RecordingFinishedEvent) {
        if isSleepModeActive, !event.isSessionRecording {
            let sleepEvent = RecordingFinishedEvent(
                fileURL: event.fileURL,
                peakDB: event.peakDB,
                averageDB: event.averageDB,
                startedAt: event.startedAt,
                endedAt: event.endedAt,
                noiseType: event.noiseType,
                segmentIndex: event.segmentIndex,
                latitude: event.latitude,
                longitude: event.longitude,
                isSessionRecording: false,
                segmentGroupID: event.segmentGroupID,
                isSleepAnomalyClip: true
            )
            onSleepAnomalyClipFinished?(sleepEvent)
            onRecordingFinished?(sleepEvent)
            return
        }

        if event.isSessionRecording,
           isAwaitingStopSaveDecision || isProcessingMonitoringStop {
            deferredSessionRecording = event
            return
        }

        if !event.isSessionRecording, isMonitoring || isAwaitingStopSaveDecision {
            currentMonitoringSegmentSaveCount += 1
        }
        onRecordingFinished?(event)
    }
    func prepareForBackgroundIfNeeded() {
        guard backgroundMonitoringEnabled else { return }
        guard !isMonitoring else {
            try? reconfigureAudioSessionForCurrentState()
            return
        }

        if permissionGranted {
            startMonitoring()
        } else {
            Task { await requestPermissionAndStart() }
        }
    }

    func handleDidEnterBackground() {
        isAppInBackground = true
        if isMonitoring {
            voiceRecorder.emergencyFinalizeForLifecycleEvent()
        }
        onVideoEmergencyFinalize?()
        guard backgroundMonitoringEnabled else { return }
        if !isMonitoring, permissionGranted {
            startMonitoring()
        }
        keepAliveInBackgroundIfNeeded()
    }

    func handleDidBecomeActive() {
        isAppInBackground = false
        resumeMonitoringIfNeededAfterForeground()
        if isSleepModeActive {
            lastSleepSampleTime = Date.distantPast
        }
    }

    func configureSleepMode(active: Bool, sleepSessionID: UUID?) {
        isSleepModeActive = active
        self.sleepSessionID = sleepSessionID
        voiceRecorder.sessionTrackEnabled = !active
        if active {
            voiceActivatedEnabled = true
            voiceRecorder.voiceActivatedEnabled = true
            lastSleepSampleTime = Date()
            lastSleepLiveActivityTime = Date.distantPast
        }
    }

    func applySleepVADThresholds(high: Float, low: Float) {
        guard isSleepModeActive else { return }
        isNormalizingThresholds = true
        highThreshold = high
        lowThreshold = low
        voiceRecorder.highThreshold = high
        voiceRecorder.lowThreshold = low
        isNormalizingThresholds = false
    }

    /// 为媒体播放让路：完全停止引擎与 tap，并清零仪表显示（不自动恢复）。
    func suspendMonitoringForPlayback() {
        if isMonitoring {
            stopMonitoring(presentSessionSavePrompt: false)
        }
        resetStatistics()
    }

    func resetStatistics() {
        currentDB = 0
        lastDBFS = 0
        maxDB = 0
        minDB = 0
        sessionMinDB = 120
        averageDB = 0
        leq = 0
        history.removeAll()
        historyBuffer.reset()
        leqCalculator.reset()
        slidingAverage = SlidingAverage(windowSize: 8)
        sampleCount = 0
        sessionSumDB = 0
        fftSampleRing.reset()
        uiFrameCounter = 0
        spectrumPeakTracker.resetPeaks()
    }

    private func enforcePremiumFeatureAccessSilently() {
        guard !SubscriptionManager.shared.isPremiumUser else { return }
        isLoadingPersistedSettings = true
        if aiClassificationEnabled {
            aiClassificationEnabled = false
            aiFilterLabels = []
        }
        isLoadingPersistedSettings = false
    }

    private var currentFFTConfiguration: FFTConfiguration {
        FFTConfiguration.forHighSensitivityMode(isHighSensitivityMode)
    }

    private func configureFFTDSPBuffers(for configuration: FFTConfiguration) {
        spectrumPeakTracker.configure(for: configuration)
        fftAnalyzer?.reconfigure(to: configuration)
    }

    /// Waits for in-flight tap buffers to finish before reconfiguring DSP state.
    private func drainProcessingQueue() {
        processingQueue.sync {}
    }

    func updateWeighting(_ type: WeightingType) {
        guard !isHighSensitivityMode else { return }
        weightingType = type
        DeviceCalibrationStore.weightingType = type
        weightingFilter?.updateWeighting(type)
        AppTelemetry.logProductEvent(
            "weighting_changed",
            parameters: ["weighting": type.rawValue.lowercased()]
        )
    }

    func persistSettings() {
        VoiceSettingsStore.persist(
            highThreshold: highThreshold,
            lowThreshold: lowThreshold,
            voiceActivatedEnabled: voiceActivatedEnabled,
            backgroundMonitoringEnabled: backgroundMonitoringEnabled,
            aiClassificationEnabled: aiClassificationEnabled,
            aiFilterLabels: aiFilterLabels
        )
    }

    private func applyNormalizedThresholds(adjustingHigh: Bool) {
        let pair = VoiceThresholdValidator.normalized(high: highThreshold, low: lowThreshold)
        isNormalizingThresholds = true
        highThreshold = pair.high
        lowThreshold = pair.low
        voiceRecorder.highThreshold = pair.high
        voiceRecorder.lowThreshold = pair.low
        isNormalizingThresholds = false
        if !isLoadingPersistedSettings {
            persistSettings()
        }
    }

    private func restartPipeline() {
        guard isMonitoring else { return }
        let pipelineSignpost = ModeSwitchPerformance.begin(.restartPipelineTotal)
        defer { ModeSwitchPerformance.end(.restartPipelineTotal, pipelineSignpost) }

        ModeSwitchPerformance.mark(.restartPipelineBegin)

        let removeTapSignpost = ModeSwitchPerformance.begin(.removeTap)
        safeRemoveInputTap()
        drainProcessingQueue()
        ModeSwitchPerformance.end(.removeTap, removeTapSignpost)

        do {
            try setupAudioPipeline()
        } catch {
            setUserError(
                AudioSessionError.wrap(error).localizedDescription,
                context: "mode_switch_pipeline"
            )
            ModeSwitchPerformance.mark(.restartPipelineEnd)
            return
        }
        ModeSwitchPerformance.mark(.restartPipelineEnd)
    }

    /// Restores the mic pipeline after another feature (e.g. camera preview / fullscreen ad) used the audio session.
    func restoreMonitoringAfterExternalSession() {
        guard isMonitoring else { return }
        recoverMonitoringPipeline(showErrorOnFailure: false, forceSessionReactivation: true)
    }

    /// Returns whether the AVAudioEngine graph is currently running.
    var isAudioEngineRunning: Bool {
        audioEngine.isRunning
    }

    /// Clears a stuck "monitoring" intent after the pipeline failed to recover (e.g. post-ad -10868).
    func abandonFailedMonitoringPipeline() {
        guard isMonitoring else { return }
        safeRemoveInputTap()
        drainProcessingQueue()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        locationProvider.stopUpdating()
        noiseClassifier?.stop()
        isMonitoring = false
        recordingState = .idle
        AppTelemetry.setMonitoringActive(false)
        Task {
            await LiveActivityManager.shared.endLiveActivity()
        }
    }

    @discardableResult
    private func reconfigureAudioSessionForCurrentState(forceActivation: Bool = false) throws -> Bool {
        if forceActivation {
            try BackgroundAudioSession.forceActivateMeasurementAfterExternalInterruption(
                backgroundEnabled: backgroundMonitoringEnabled
            )
        } else {
            try BackgroundAudioSession.activateForMeasurement(
                backgroundEnabled: backgroundMonitoringEnabled,
                skipSessionActivation: audioEngine.isRunning
            )
        }
        return true
    }

    private func keepAliveInBackgroundIfNeeded() {
        guard backgroundMonitoringEnabled, isMonitoring else { return }
        recoverMonitoringPipeline(showErrorOnFailure: false, forceSessionReactivation: false)
    }

    private func resumeMonitoringIfNeededAfterForeground() {
        guard isMonitoring else { return }
        recoverMonitoringPipeline(showErrorOnFailure: true, forceSessionReactivation: true)
        if isMonitoring, !audioEngine.isRunning {
            abandonFailedMonitoringPipeline()
        }
    }

    private func recoverMonitoringPipeline(
        showErrorOnFailure: Bool,
        forceSessionReactivation: Bool
    ) {
        do {
            safeRemoveInputTap()
            drainProcessingQueue()
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            audioEngine.reset()
            // Recreate the engine so input-node formats match the post-ad hardware rate.
            audioEngine = AVAudioEngine()

            try reconfigureAudioSessionForCurrentState(forceActivation: forceSessionReactivation)
            try setupAudioPipeline()
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            guard showErrorOnFailure, !audioEngine.isRunning else { return }
            setUserError(
                AudioSessionError.wrap(error).localizedDescription,
                context: "pipeline_recovery"
            )
        }
    }

    private func teardownFailedEngineStart() {
        safeRemoveInputTap()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        isMonitoring = false
    }

    private func installAudioSessionObservers() {
        let center = NotificationCenter.default

        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAudioInterruption(notification)
            }
        }

        mediaResetObserver = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeMonitoringIfNeededAfterForeground()
            }
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let type = BackgroundAudioSession.interruptionType(in: notification) else { return }

        switch type {
        case .began:
            voiceRecorder.emergencyFinalizeForLifecycleEvent()
            onVideoEmergencyFinalize?()
            if isMonitoring {
                safeRemoveInputTap()
                drainProcessingQueue()
                if audioEngine.isRunning {
                    audioEngine.stop()
                }
                audioEngine.reset()
                audioEngine = AVAudioEngine()
            }
        case .ended:
            // Ads often end interruptions without `.shouldResume`; still recover if we intend to monitor.
            guard isMonitoring else { return }
            resumeMonitoringIfNeededAfterForeground()
        @unknown default:
            break
        }
    }

    private func setupAudioPipeline() throws {
        let trace = ModeSwitchPerformance.shouldTracePipelineSetup()
        let setupSignpost = trace ? ModeSwitchPerformance.begin(.setupPipelineTotal) : nil
        if trace {
            ModeSwitchPerformance.mark(.setupPipelineBegin)
        }
        defer {
            if trace, let setupSignpost {
                ModeSwitchPerformance.end(.setupPipelineTotal, setupSignpost)
                ModeSwitchPerformance.mark(.setupPipelineEnd)
            }
        }

        // Access inputNode before prepare()/start(). A fresh AVAudioEngine crashes in
        // prepare() with "inputNode != nullptr || outputNode != nullptr" if neither
        // node has been materialized yet.
        let inputNode = audioEngine.inputNode
        let tapFormat = try resolvedInputTapFormat(for: inputNode)
        let sampleRate = tapFormat.sampleRate
        let classifierFormat = tapFormat
        let weighting = effectiveWeighting

        weightingFilter = ModeSwitchPerformance.measure(.weightingFilter, when: trace) {
            AudioWeightingFilter(type: weighting, sampleRate: sampleRate)
        }
        fftAnalyzer = ModeSwitchPerformance.measure(.fftAnalyzer, when: trace) {
            FFTAnalyzer(
                sampleRate: sampleRate,
                configuration: currentFFTConfiguration
            )
        }
        configureFFTDSPBuffers(for: currentFFTConfiguration)
        ModeSwitchPerformance.measure(.voiceRecorderConfigure, when: trace) {
            voiceRecorder.configure(sampleRate: sampleRate)
        }
        noiseClassifier = nil

        if aiClassificationEnabled, SubscriptionManager.shared.isPremiumUser {
            let classifier = NoiseClassifierManager()
            classifier.onClassification = { [weak self] label, confidence in
                self?.cachedNoiseLabel = label
                Task { @MainActor in
                    self?.latestNoiseLabel = label
                    self?.latestNoiseConfidence = confidence
                    self?.voiceRecorder.setNoiseType(label)
                }
            }
            classifier.onFailure = { [weak self] _ in
                Task { @MainActor in
                    self?.aiClassificationErrorMessage = L10n.errorAiClassificationFailed
                }
            }
            ModeSwitchPerformance.measure(.noiseClassifierSetup, when: trace) {
                classifier.setup(format: classifierFormat)
            }
            noiseClassifier = classifier
        }

        safeRemoveInputTap()
        ModeSwitchPerformance.measure(.installTap, when: trace) {
            // Must match hardware input sample rate or AVAudioEngine aborts the process.
            inputNode.installTap(
                onBus: 0,
                bufferSize: SPLCalculator.tapBufferSize,
                format: tapFormat
            ) { [weak self] buffer, time in
                self?.processingQueue.async {
                    self?.processBuffer(buffer, time: time)
                }
            }
        }
    }

    private func safeRemoveInputTap() {
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Hardware input format for bus 0. `installTap` requires this sample rate exactly.
    private func resolvedInputTapFormat(for inputNode: AVAudioInputNode) throws -> AVAudioFormat {
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        if hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 {
            return hardwareFormat
        }

        // Fallback: some devices expose a valid output bus before input bus settles.
        let outputFormat = inputNode.outputFormat(forBus: 0)
        if outputFormat.sampleRate > 0, outputFormat.channelCount > 0 {
            let sessionRate = AVAudioSession.sharedInstance().sampleRate
            if sessionRate <= 0 || abs(outputFormat.sampleRate - sessionRate) <= 1 {
                return outputFormat
            }
            AppTelemetry.log(
                "audio_tap_format_mismatch bus_rate=\(outputFormat.sampleRate) session_rate=\(sessionRate)"
            )
        }

        AppTelemetry.log(
            "audio_tap_format_invalid hw_rate=\(hardwareFormat.sampleRate) out_rate=\(outputFormat.sampleRate)"
        )
        throw AudioSessionError.configurationFailed(
            "Invalid audio input format (sampleRate=\(hardwareFormat.sampleRate))"
        )
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let signpost = PerformanceSignpost.begin(.processBuffer)
        defer { PerformanceSignpost.end(.processBuffer, signpost) }

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0, buffer.format.sampleRate > 0 else { return }

        if filteredScratch.count < frameLength {
            filteredScratch = [Float](repeating: 0, count: frameLength)
        }

        if isHighSensitivityMode {
            for i in 0..<frameLength {
                filteredScratch[i] = channelData[i]
            }
        } else {
            weightingFilter?.process(
                input: channelData,
                output: &filteredScratch,
                frameLength: frameLength
            )
        }

        let offset = cachedCalibrationOffset
        var dbSPL: Float = 0
        var dbfs: Float = 0
        var smoothed: Float = 0

        filteredScratch.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            let measurement = SPLCalculator.spl(
                from: base,
                frameLength: frameLength,
                calibrationOffset: offset
            )
            dbSPL = measurement.dbSPL
            dbfs = measurement.dbfs
            smoothed = slidingAverage.add(dbSPL)

            voiceRecorder.process(
                filteredSamples: base,
                frameLength: frameLength,
                dbSPL: dbSPL,
                format: buffer.format,
                vadGatedByFilter: shouldProcessVoiceRecorder
            )
        }

        leqCalculator.addSample(dbSPL: dbSPL)
        sampleCount += 1
        sessionSumDB += smoothed

        classifierBufferSkipCounter += 1
        if classifierBufferSkipCounter % 3 == 0 {
            noiseClassifier?.append(buffer: buffer, at: time)
        }

        filteredScratch.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            fftSampleRing.write(base, count: frameLength)
        }

        let now = Date()
        if isSleepModeActive,
           now.timeIntervalSince(lastSleepSampleTime) >= SleepMeasurementPersistence.sampleInterval {
            lastSleepSampleTime = now
            Task { @MainActor in
                self.onSleepSampleDue?()
            }
        }

        guard now.timeIntervalSince(lastUIUpdate) >= Performance.uiInterval else { return }
        lastUIUpdate = now
        uiFrameCounter += 1

        var freshLiveDecibels: [Float]?
        var analyzedSampleRate: Double?
        var analyzedFFTSize: Int?
        let fftConfiguration = currentFFTConfiguration
        let shouldComputeSpectrum = !(isSleepModeActive && isAppInBackground)
        if shouldComputeSpectrum,
           uiFrameCounter % Performance.spectrumEveryNthUIFrame == 0,
           fftSampleRing.isReadyForAnalysis(windowSize: fftConfiguration.fftSize) {
            fftSampleRing.copyLatestWindow(
                into: &fftScratch,
                windowSize: fftConfiguration.fftSize
            )
            if let analyzed = fftScratch.withUnsafeBufferPointer({ ptr in
                fftAnalyzer?.analyze(
                    channelData: ptr.baseAddress!,
                    frameLength: fftConfiguration.fftSize,
                    calibrationOffset: offset
                )
            }) {
                freshLiveDecibels = analyzed.decibels
                analyzedSampleRate = analyzed.sampleRate
                analyzedFFTSize = analyzed.fftSize
            }
        }

        let spectrum = spectrumPeakTracker.processFrame(
            liveDecibels: freshLiveDecibels,
            sampleRate: analyzedSampleRate,
            fftSize: analyzedFFTSize
        )

        historyBuffer.append(smoothed)
        var historySnapshot: [Float] = []
        historyBuffer.copyChronological(into: &historySnapshot)

        let snapshotSmoothed = smoothed
        let snapshotLeq = leqCalculator.leq
        let snapshotMax = max(maxDB, snapshotSmoothed)
        sessionMinDB = min(sessionMinDB, snapshotSmoothed)
        let snapshotMin = sessionMinDB
        let snapshotAvg = sampleCount > 0 ? sessionSumDB / Float(sampleCount) : snapshotSmoothed
        let state = voiceRecorder.state
        let spectrumCopy = spectrum
        let snapshotDBFS = dbfs
        uiPublishGeneration += 1
        let generation = uiPublishGeneration
        let snapshot = UIPublishSnapshot(
            generation: generation,
            lastDBFS: snapshotDBFS,
            currentDB: snapshotSmoothed,
            maxDB: snapshotMax,
            minDB: snapshotMin,
            averageDB: snapshotAvg,
            leq: snapshotLeq,
            recordingState: state,
            spectrum: spectrumCopy,
            history: historySnapshot
        )

        let shouldPushLiveActivity = !isSleepModeActive
            || now.timeIntervalSince(lastSleepLiveActivityTime) >= 60
        if shouldPushLiveActivity {
            if isSleepModeActive {
                lastSleepLiveActivityTime = now
            }
            LiveActivityManager.shared.pushAudioBufferUpdate(
                currentDB: snapshotSmoothed,
                isHighSensitivity: isHighSensitivityMode,
                weightingType: weightingType,
                recordingState: state,
                historyTail: historySnapshot
            )
        }

        Task { @MainActor in
            self.publishUISnapshot(snapshot)
        }
    }

    private func publishUISnapshot(_ snapshot: UIPublishSnapshot) {
        guard snapshot.generation == uiPublishGeneration else { return }
        let signpost = PerformanceSignpost.begin(.publishUI)
        defer { PerformanceSignpost.end(.publishUI, signpost) }

        lastDBFS = snapshot.lastDBFS
        currentDB = snapshot.currentDB
        maxDB = snapshot.maxDB
        minDB = snapshot.minDB
        averageDB = snapshot.averageDB
        leq = snapshot.leq
        recordingState = snapshot.recordingState
        if isSleepModeActive {
            onSleepMetricsRefresh?(snapshot.currentDB, snapshot.minDB, snapshot.leq)
        }
        if let spectrum = snapshot.spectrum {
            latestSpectrum = spectrum
        }
        history = snapshot.history
    }

    private func setUserError(_ message: String, context: String) {
        errorMessage = message
        AppTelemetry.recordMessage(message, context: context)
    }
}

/// Thread-safe spectrum peak-hold state accessed from `processingQueue` and MainActor reconfiguration.
private final class SpectrumPeakTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var peakAmounts: [Float]
    private var lastLiveDecibels: [Float]?
    private var lastSampleRate: Double
    private var lastFFTSize: Int

    /// Matches `NoiseMonitorEngine.Performance.peakDecayFactor`.
    private static let peakDecayFactor: Float = 0.985

    init(binCount: Int) {
        let floor = SpectrumDSPGuards.analyzerDecibelFloor
        peakAmounts = [Float](repeating: floor, count: binCount)
        lastSampleRate = 44_100
        lastFFTSize = FFTConfiguration.standard.fftSize
    }

    func configure(for configuration: FFTConfiguration) {
        lock.lock()
        defer { lock.unlock() }

        let requiredBins = configuration.binCount
        let floor = SpectrumDSPGuards.analyzerDecibelFloor
        if peakAmounts.count != requiredBins {
            peakAmounts = [Float](repeating: floor, count: requiredBins)
        } else {
            for index in peakAmounts.indices {
                peakAmounts[index] = floor
            }
        }
        lastLiveDecibels = nil
    }

    func resetPeaks() {
        lock.lock()
        defer { lock.unlock() }

        let floor = SpectrumDSPGuards.analyzerDecibelFloor
        for index in peakAmounts.indices {
            peakAmounts[index] = floor
        }
        lastLiveDecibels = nil
    }

    /// 指数衰减 + 峰值锁定；每 UI 帧调用一次（processingQueue）。
    func processFrame(
        liveDecibels: [Float]?,
        sampleRate: Double? = nil,
        fftSize: Int? = nil
    ) -> FFTSpectrum? {
        lock.lock()
        defer { lock.unlock() }

        if let liveDecibels, let sampleRate, let fftSize {
            lastLiveDecibels = liveDecibels
            lastSampleRate = sampleRate
            lastFFTSize = fftSize
        }

        advancePeakAmountsLocked(with: liveDecibels)

        guard let live = lastLiveDecibels else { return nil }
        let peakSnapshot = Array(peakAmounts.prefix(live.count))
        return FFTSpectrum(
            decibels: live,
            sampleRate: lastSampleRate,
            fftSize: lastFFTSize,
            peakDecibels: peakSnapshot
        )
    }

    private func advancePeakAmountsLocked(with current: [Float]?) {
        let floor = SpectrumDSPGuards.analyzerDecibelFloor
        let decayFactor = Self.peakDecayFactor

        for index in peakAmounts.indices {
            if index < SpectrumDSPGuards.pathDrawingMinBin {
                peakAmounts[index] = floor
                continue
            }
            let decayedPeak = peakAmounts[index] * decayFactor
            let decayed = decayedPeak < floor ? floor : decayedPeak
            if let current, index < current.count {
                peakAmounts[index] = max(decayed, current[index])
            } else {
                peakAmounts[index] = decayed
            }
        }
    }
}
