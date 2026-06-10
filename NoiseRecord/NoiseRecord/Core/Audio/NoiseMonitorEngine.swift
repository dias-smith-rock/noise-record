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
    var minDB: Float = 120
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
        didSet { voiceRecorder.highThreshold = highThreshold }
    }
    var lowThreshold: Float = 48 {
        didSet { voiceRecorder.lowThreshold = lowThreshold }
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
    var aiFilterLabels: Set<String> = []

    private let audioEngine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.noiseapp.processing", qos: .userInteractive)
    private var weightingFilter: AudioWeightingFilter?
    private var fftAnalyzer: FFTAnalyzer?
    private var leqCalculator = LeqCalculator()
    private var slidingAverage = SlidingAverage(windowSize: 8)
    private var sessionSumDB: Float = 0
    private var filteredScratch: [Float] = []
    private var fftFrameAccumulator: [Float] = []
    private let voiceRecorder = VoiceActivatedRecorder()
    private var noiseClassifier: NoiseClassifierManager?
    private var sampleCount = 0
    private var lastUIUpdate = Date.distantPast
    private var cachedNoiseLabel: String?
    private var interruptionObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?
    private(set) var currentSessionRecordingIDs: [UUID] = []
    var isDiscardingSessionRecordings = false

    var onRecordingFinished: ((RecordingFinishedEvent) -> Void)?

    var shouldPromptForRecordingsOnStop: Bool {
        voiceActivatedEnabled && (!currentSessionRecordingIDs.isEmpty || recordingState != .idle)
    }

    var currentSessionRecordingCount: Int {
        currentSessionRecordingIDs.count
    }

    /// Effective weighting applied to the audio pipeline.
    var effectiveWeighting: WeightingType {
        isHighSensitivityMode ? .z : weightingType
    }

    init() {
        highThreshold = UserDefaults.standard.object(forKey: "settings.highThreshold") as? Float ?? 55
        lowThreshold = UserDefaults.standard.object(forKey: "settings.lowThreshold") as? Float ?? 48
        voiceActivatedEnabled = UserDefaults.standard.bool(forKey: "settings.voiceActivated")
        backgroundMonitoringEnabled = UserDefaults.standard.bool(forKey: "settings.backgroundMonitoring")
        aiClassificationEnabled = UserDefaults.standard.bool(forKey: "settings.aiClassification")
        isHighSensitivityMode = DeviceCalibrationStore.isHighSensitivityMode

        voiceRecorder.highThreshold = highThreshold
        voiceRecorder.lowThreshold = lowThreshold
        voiceRecorder.onRecordingFinished = { [weak self] event in
            Task { @MainActor in
                self?.onRecordingFinished?(event)
            }
        }

        installAudioSessionObservers()
    }

    func requestPermissionAndStart() async {
        permissionGranted = await AudioSessionManager.requestPermission()
        guard permissionGranted else {
            errorMessage = AudioSessionError.permissionDenied.localizedDescription
            return
        }
        startMonitoring()
    }

    /// Ensures high-sensitivity monitoring is running for video evidence overlay.
    @discardableResult
    func ensureMonitoringForVideoEvidence() async -> Bool {
        if !permissionGranted {
            permissionGranted = await AudioSessionManager.requestPermission()
            guard permissionGranted else {
                errorMessage = AudioSessionError.permissionDenied.localizedDescription
                return false
            }
        }

        if !isHighSensitivityMode {
            isHighSensitivityMode = true
        }

        if !isMonitoring {
            startMonitoring()
        }

        return isMonitoring
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        errorMessage = nil

        do {
            try reconfigureAudioSessionForCurrentState()
        } catch {
            errorMessage = AudioSessionError.wrap(error).localizedDescription
            return
        }

        resetStatistics()
        beginMonitoringSession()
        setupAudioPipeline()

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isMonitoring = true
        } catch {
            errorMessage = "音频引擎启动失败：\(error.localizedDescription)"
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
    }

    func resetStatistics() {
        currentDB = 0
        lastDBFS = 0
        maxDB = 0
        minDB = 120
        averageDB = 0
        leq = 0
        history.removeAll()
        leqCalculator.reset()
        slidingAverage = SlidingAverage(windowSize: 8)
        sampleCount = 0
        sessionSumDB = 0
        fftFrameAccumulator.removeAll()
    }

    func updateWeighting(_ type: WeightingType) {
        guard !isHighSensitivityMode else { return }
        weightingType = type
        DeviceCalibrationStore.weightingType = type
        weightingFilter?.updateWeighting(type)
    }

    func persistSettings() {
        UserDefaults.standard.set(highThreshold, forKey: "settings.highThreshold")
        UserDefaults.standard.set(lowThreshold, forKey: "settings.lowThreshold")
        UserDefaults.standard.set(voiceActivatedEnabled, forKey: "settings.voiceActivated")
        UserDefaults.standard.set(backgroundMonitoringEnabled, forKey: "settings.backgroundMonitoring")
        UserDefaults.standard.set(aiClassificationEnabled, forKey: "settings.aiClassification")
    }

    private func restartPipeline() {
        guard isMonitoring else { return }
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
            try reconfigureAudioSessionForCurrentState()
            guard !audioEngine.isRunning else { return }
            setupAudioPipeline()
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            guard showErrorOnFailure, !audioEngine.isRunning else { return }
            errorMessage = AudioSessionError.wrap(error).localizedDescription
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

        let offset = DeviceCalibrationStore.totalOffset
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

        noiseClassifier?.append(buffer: buffer, at: time)

        fftFrameAccumulator.append(contentsOf: filteredScratch.prefix(frameLength))

        let fftSize = 2048
        var spectrum: FFTSpectrum?
        if fftFrameAccumulator.count >= fftSize {
            let fftSlice = Array(fftFrameAccumulator.suffix(fftSize))
            spectrum = fftSlice.withUnsafeBufferPointer { ptr in
                fftAnalyzer?.analyze(channelData: ptr.baseAddress!, frameLength: fftSize)
            }
            if fftFrameAccumulator.count > fftSize {
                fftFrameAccumulator.removeFirst(fftFrameAccumulator.count - fftSize)
            }
        }

        let now = Date()
        guard now.timeIntervalSince(lastUIUpdate) >= 0.02 else { return }
        lastUIUpdate = now

        let snapshotSmoothed = smoothed
        let snapshotLeq = leqCalculator.leq
        let snapshotMax = max(maxDB, snapshotSmoothed)
        let snapshotMin = min(minDB, snapshotSmoothed)
        let snapshotAvg = sampleCount > 0 ? sessionSumDB / Float(sampleCount) : snapshotSmoothed
        let state = voiceRecorder.state
        let spectrumCopy = spectrum
        let snapshotDBFS = dbfs

        Task { @MainActor in
            self.lastDBFS = snapshotDBFS
            self.currentDB = snapshotSmoothed
            self.maxDB = snapshotMax
            self.minDB = snapshotMin
            self.averageDB = snapshotAvg
            self.leq = snapshotLeq
            self.recordingState = state
            if let spectrumCopy {
                self.latestSpectrum = spectrumCopy
            }
            self.history.append(snapshotSmoothed)
            if self.history.count > 300 {
                self.history.removeFirst(self.history.count - 300)
            }
        }
    }
}
