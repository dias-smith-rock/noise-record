import Accelerate
import AVFoundation
import Foundation

struct NoiseLevelSnapshot: Sendable {
    let currentDB: Float
    let maxDB: Float
    let minDB: Float
    let averageDB: Float
    let leq: Float
    let weighting: WeightingType
    let timestamp: Date
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
            DeviceCalibrationStore.isHighSensitivityMode = isHighSensitivityMode
            if isMonitoring {
                restartPipeline()
            }
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
    var voiceActivatedEnabled = false
    var backgroundMonitoringEnabled = false {
        didSet {
            guard backgroundMonitoringEnabled != oldValue else { return }
            persistSettings()
            if isMonitoring {
                try? reconfigureAudioSessionForCurrentState()
            }
        }
    }
    var aiClassificationEnabled = false
    var aiFilterLabels: Set<String> = [] {
        didSet {
            guard !isLoadingPersistedSettings else { return }
            persistSettings()
        }
    }
    var aiClassificationErrorMessage: String?
    var showMicrophonePermissionDenied = false

    private let audioEngine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.noiseapp.processing", qos: .userInteractive)
    private var weightingFilter: AudioWeightingFilter?
    private var fftAnalyzer: FFTAnalyzer?
    private var leqCalculator = LeqCalculator()
    private var slidingAverage = SlidingAverage(windowSize: 8)
    private var sessionSumDB: Float = 0
    private var filteredScratch: [Float] = []
    private var historyBuffer = FloatTimeSeriesBuffer(capacity: 300)
    private var fftSampleRing = FFTSampleRing(capacity: 2048)
    private var fftScratch = [Float](repeating: 0, count: 2048)
    private var uiFrameCounter = 0
    private let voiceRecorder = VoiceActivatedRecorder()
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
        /// Spectrum FFT is heavier; update every N UI frames (~5 Hz).
        static let spectrumEveryNthUIFrame = 3
    }
    private var cachedNoiseLabel: String?
    private var isNormalizingThresholds = false
    private var isLoadingPersistedSettings = false
    private var interruptionObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?
    private var calibrationObserver: NSObjectProtocol?
    private(set) var currentSessionRecordingIDs: [UUID] = []
    var isDiscardingSessionRecordings = false
    private(set) var deferredRecordingsForStopPrompt: [RecordingFinishedEvent] = []
    private(set) var isAwaitingStopSaveDecision = false

    var onRecordingFinished: ((RecordingFinishedEvent) -> Void)?

    var shouldPromptForRecordingsOnStop: Bool {
        voiceActivatedEnabled && (!currentSessionRecordingIDs.isEmpty || recordingState != .idle)
    }

    /// Voice-activated capture is armed and the monitor pipeline is running.
    var isVoiceRecordingRunning: Bool {
        voiceActivatedEnabled && isMonitoring
    }

    var currentSessionRecordingCount: Int {
        currentSessionRecordingIDs.count
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
        isNormalizingThresholds = false
        isLoadingPersistedSettings = false

        voiceRecorder.onRecordingFinished = { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if self.isAwaitingStopSaveDecision {
                    self.deferredRecordingsForStopPrompt.append(event)
                    return
                }
                self.onRecordingFinished?(event)
            }
        }

        installAudioSessionObservers()
        installCalibrationObserver()
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
            isHighSensitivityMode = true
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

        do {
            try reconfigureAudioSessionForCurrentState()
        } catch {
            setUserError(AudioSessionError.wrap(error).localizedDescription, context: "audio_session_config")
            return
        }

        resetStatistics()
        refreshCalibrationOffset()
        beginMonitoringSession()
        setupAudioPipeline()

        do {
            audioEngine.prepare()
            try audioEngine.start()
            try primeAudioCaptureAfterEngineRunning()
            isMonitoring = true
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
            if audioEngine.isRunning {
                audioEngine.inputNode.removeTap(onBus: 0)
                audioEngine.stop()
            }
            setUserError(L10n.errorEngineStartFailed(error.localizedDescription), context: "engine_start")
        }
    }

    func noteRecordingSaved(id: UUID) {
        guard isMonitoring else { return }
        currentSessionRecordingIDs.append(id)
    }

    func beginMonitoringSession() {
        currentSessionRecordingIDs.removeAll()
        isDiscardingSessionRecordings = false
    }

    func clearMonitoringSessionTracking() {
        currentSessionRecordingIDs.removeAll()
        isDiscardingSessionRecordings = false
        deferredRecordingsForStopPrompt.removeAll()
        isAwaitingStopSaveDecision = false
    }

    func prepareStopWithSavePrompt() {
        isAwaitingStopSaveDecision = true
        deferredRecordingsForStopPrompt.removeAll()
    }

    func commitDeferredRecordings() {
        let events = deferredRecordingsForStopPrompt
        deferredRecordingsForStopPrompt.removeAll()
        isAwaitingStopSaveDecision = false
        for event in events {
            onRecordingFinished?(event)
        }
    }

    func discardDeferredRecordings() {
        for event in deferredRecordingsForStopPrompt {
            try? FileManager.default.removeItem(at: event.fileURL)
        }
        deferredRecordingsForStopPrompt.removeAll()
        isAwaitingStopSaveDecision = false
    }

    /// Starts monitoring while the app is still foreground-eligible so background audio can continue.
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
        guard backgroundMonitoringEnabled else { return }
        if !isMonitoring, permissionGranted {
            startMonitoring()
        }
        keepAliveInBackgroundIfNeeded()
    }

    func handleDidBecomeActive() {
        resumeMonitoringIfNeededAfterForeground()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        voiceRecorder.forceStop()
        noiseClassifier?.stop()
        isMonitoring = false
        recordingState = .idle
        minDB = 0
        sessionMinDB = 120
        AppTelemetry.setMonitoringActive(false)
        Task {
            await LiveActivityManager.shared.endLiveActivity()
        }
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
    }

    func updateWeighting(_ type: WeightingType) {
        guard !isHighSensitivityMode else { return }
        weightingType = type
        DeviceCalibrationStore.weightingType = type
        weightingFilter?.updateWeighting(type)
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
        audioEngine.inputNode.removeTap(onBus: 0)
        setupAudioPipeline()
    }

    /// Re-activates the session and reinstalls the tap after the engine is running,
    /// matching the mic priming that happens when entering the video evidence tab.
    private func primeAudioCaptureAfterEngineRunning() throws {
        try BackgroundAudioSession.activateForMeasurement(
            backgroundEnabled: backgroundMonitoringEnabled,
            skipSessionActivation: false
        )
        audioEngine.inputNode.removeTap(onBus: 0)
        setupAudioPipeline()
    }

    /// Restores the mic pipeline after another feature (e.g. camera preview) used the audio session.
    func restoreMonitoringAfterExternalSession() {
        guard isMonitoring else { return }
        recoverMonitoringPipeline(showErrorOnFailure: false)
    }

    @discardableResult
    private func reconfigureAudioSessionForCurrentState() throws -> Bool {
        try BackgroundAudioSession.activateForMeasurement(
            backgroundEnabled: backgroundMonitoringEnabled,
            skipSessionActivation: audioEngine.isRunning
        )
        return true
    }

    private func keepAliveInBackgroundIfNeeded() {
        guard backgroundMonitoringEnabled, isMonitoring else { return }
        recoverMonitoringPipeline(showErrorOnFailure: false)
    }

    private func resumeMonitoringIfNeededAfterForeground() {
        guard isMonitoring else { return }
        recoverMonitoringPipeline(showErrorOnFailure: true)
    }

    private func recoverMonitoringPipeline(showErrorOnFailure: Bool) {
        do {
            if audioEngine.isRunning {
                try primeAudioCaptureAfterEngineRunning()
            } else {
                try reconfigureAudioSessionForCurrentState()
                audioEngine.prepare()
                try audioEngine.start()
                try primeAudioCaptureAfterEngineRunning()
            }
        } catch {
            guard showErrorOnFailure else { return }
            setUserError(
                AudioSessionError.wrap(error).localizedDescription,
                context: "pipeline_recovery"
            )
        }
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
            break
        case .ended:
            guard BackgroundAudioSession.shouldResumeAfterInterruption(notification) else { return }
            resumeMonitoringIfNeededAfterForeground()
        @unknown default:
            break
        }
    }

    private func setupAudioPipeline() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let weighting = effectiveWeighting

        weightingFilter = AudioWeightingFilter(type: weighting, sampleRate: sampleRate)
        fftAnalyzer = FFTAnalyzer(bufferSize: 2048, sampleRate: sampleRate)
        voiceRecorder.configure(sampleRate: sampleRate)
        noiseClassifier = nil

        if aiClassificationEnabled {
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
            classifier.setup(format: format)
            noiseClassifier = classifier
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: SPLCalculator.tapBufferSize,
            format: format
        ) { [weak self] buffer, time in
            self?.processingQueue.async {
                self?.processBuffer(buffer, time: time)
            }
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let signpost = PerformanceSignpost.begin(.processBuffer)
        defer { PerformanceSignpost.end(.processBuffer, signpost) }

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

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

            if voiceActivatedEnabled {
                let shouldRecord: Bool
                if aiClassificationEnabled && !aiFilterLabels.isEmpty {
                    shouldRecord = cachedNoiseLabel.map { aiFilterLabels.contains($0) } ?? false
                } else {
                    shouldRecord = true
                }
                if shouldRecord {
                    voiceRecorder.process(
                        filteredSamples: base,
                        frameLength: frameLength,
                        dbSPL: dbSPL,
                        format: buffer.format
                    )
                }
            }
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
        guard now.timeIntervalSince(lastUIUpdate) >= Performance.uiInterval else { return }
        lastUIUpdate = now
        uiFrameCounter += 1

        var spectrum: FFTSpectrum?
        if uiFrameCounter % Performance.spectrumEveryNthUIFrame == 0,
           fftSampleRing.isReadyForAnalysis {
            fftSampleRing.copyLatestWindow(into: &fftScratch)
            spectrum = fftScratch.withUnsafeBufferPointer { ptr in
                fftAnalyzer?.analyze(channelData: ptr.baseAddress!, frameLength: fftScratch.count)
            }
        }

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

        LiveActivityManager.shared.pushAudioBufferUpdate(
            currentDB: snapshotSmoothed,
            isHighSensitivity: isHighSensitivityMode,
            weightingType: weightingType,
            voiceActivatedEnabled: voiceActivatedEnabled,
            recordingState: state,
            historyTail: historySnapshot
        )

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
