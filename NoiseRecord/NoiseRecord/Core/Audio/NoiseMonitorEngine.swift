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

    var highThreshold: Float = 55 {
        didSet { voiceRecorder.highThreshold = highThreshold }
    }
    var lowThreshold: Float = 48 {
        didSet { voiceRecorder.lowThreshold = lowThreshold }
    }
    var voiceActivatedEnabled = false
    var backgroundMonitoringEnabled = false
    var aiClassificationEnabled = false
    var aiFilterLabels: Set<String> = []

    private let audioEngine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.noiseapp.processing", qos: .userInteractive)
    private var weightingFilter: AudioWeightingFilter?
    private var fftAnalyzer: FFTAnalyzer?
    private var leqCalculator = LeqCalculator()
    private var slidingAverage = SlidingAverage(windowSize: 20)
    private var sessionSumDB: Float = 0
    private var filteredScratch: [Float] = []
    private var fftFrameAccumulator: [Float] = []
    private let voiceRecorder = VoiceActivatedRecorder()
    private var noiseClassifier: NoiseClassifierManager?
    private var sampleCount = 0
    private var lastUIUpdate = Date.distantPast
    private var cachedNoiseLabel: String?

    var onRecordingFinished: ((RecordingFinishedEvent) -> Void)?

    init() {
        highThreshold = UserDefaults.standard.object(forKey: "settings.highThreshold") as? Float ?? 55
        lowThreshold = UserDefaults.standard.object(forKey: "settings.lowThreshold") as? Float ?? 48
        voiceActivatedEnabled = UserDefaults.standard.bool(forKey: "settings.voiceActivated")
        backgroundMonitoringEnabled = UserDefaults.standard.bool(forKey: "settings.backgroundMonitoring")
        aiClassificationEnabled = UserDefaults.standard.bool(forKey: "settings.aiClassification")

        voiceRecorder.highThreshold = highThreshold
        voiceRecorder.lowThreshold = lowThreshold
        voiceRecorder.onRecordingFinished = { [weak self] event in
            Task { @MainActor in
                self?.onRecordingFinished?(event)
            }
        }
    }

    func requestPermissionAndStart() async {
        permissionGranted = await AudioSessionManager.requestPermission()
        guard permissionGranted else {
            errorMessage = AudioSessionError.permissionDenied.localizedDescription
            return
        }
        startMonitoring()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        errorMessage = nil

        do {
            try AudioSessionManager.configureForMeasurement(backgroundEnabled: backgroundMonitoringEnabled)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        resetStatistics()
        setupAudioPipeline()

        do {
            try audioEngine.start()
            isMonitoring = true
        } catch {
            errorMessage = "音频引擎启动失败：\(error.localizedDescription)"
        }
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
        maxDB = 0
        minDB = 120
        averageDB = 0
        leq = 0
        history.removeAll()
        leqCalculator.reset()
        slidingAverage = SlidingAverage(windowSize: 20)
        sampleCount = 0
        sessionSumDB = 0
        fftFrameAccumulator.removeAll()
    }

    func updateWeighting(_ type: WeightingType) {
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

    private func setupAudioPipeline() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate

        weightingFilter = AudioWeightingFilter(type: weightingType, sampleRate: sampleRate)
        fftAnalyzer = FFTAnalyzer(bufferSize: 2048, sampleRate: sampleRate)
        voiceRecorder.configure(sampleRate: sampleRate)

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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
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

        weightingFilter?.process(
            input: channelData,
            output: &filteredScratch,
            frameLength: frameLength
        )

        var rms: Float = 0
        filteredScratch.withUnsafeBufferPointer { ptr in
            vDSP_rmsqv(ptr.baseAddress!, 1, &rms, vDSP_Length(frameLength))
        }
        if rms < 0.000_01 { rms = 0.000_01 }

        let dbfs = 20 * log10(rms)
        let dbSPL = dbfs + DeviceCalibrationStore.totalOffset
        let smoothed = slidingAverage.add(dbSPL)

        leqCalculator.addSample(dbSPL: dbSPL)
        sampleCount += 1
        sessionSumDB += smoothed

        if voiceActivatedEnabled {
            let shouldRecord: Bool
            if aiClassificationEnabled && !aiFilterLabels.isEmpty {
                shouldRecord = cachedNoiseLabel.map { aiFilterLabels.contains($0) } ?? false
            } else {
                shouldRecord = true
            }
            if shouldRecord {
                let format = buffer.format
                filteredScratch.withUnsafeBufferPointer { ptr in
                    voiceRecorder.process(
                        filteredSamples: ptr.baseAddress!,
                        frameLength: frameLength,
                        dbSPL: dbSPL,
                        format: format
                    )
                }
            }
        }

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
        guard now.timeIntervalSince(lastUIUpdate) >= 0.05 else { return }
        lastUIUpdate = now

        let snapshotDB = dbSPL
        let snapshotSmoothed = smoothed
        let snapshotLeq = leqCalculator.leq
        let snapshotMax = max(maxDB, snapshotDB)
        let snapshotMin = min(minDB, snapshotDB)
        let snapshotAvg = sampleCount > 0 ? sessionSumDB / Float(sampleCount) : snapshotSmoothed
        let state = voiceRecorder.state
        let spectrumCopy = spectrum

        Task { @MainActor in
            self.currentDB = snapshotDB
            self.maxDB = snapshotMax
            self.minDB = snapshotMin
            self.averageDB = snapshotAvg
            self.leq = snapshotLeq
            self.recordingState = state
            if let spectrumCopy {
                self.latestSpectrum = spectrumCopy
            }
            self.history.append(snapshotDB)
            if self.history.count > 300 {
                self.history.removeFirst(self.history.count - 300)
            }
        }
    }
}
