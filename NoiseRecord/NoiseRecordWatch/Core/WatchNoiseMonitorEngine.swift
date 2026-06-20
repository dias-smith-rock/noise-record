import AVFoundation
import Foundation

@MainActor
@Observable
final class WatchNoiseMonitorEngine {
    var isMonitoring = false
    var permissionGranted = false
    var errorMessage: String?
    var runtimeNotice: String?

    var currentDB: Float = 0
    var maxDB: Float = 0
    var minDB: Float = 0
    var averageDB: Float = 0
    var leq: Float = 0

    var isHighSensitivityMode: Bool = WatchCalibrationStore.isHighSensitivityMode {
        didSet {
            WatchCalibrationStore.isHighSensitivityMode = isHighSensitivityMode
            if isMonitoring {
                restartPipeline()
            }
        }
    }

    private let audioEngine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.noiseapp.watch.processing", qos: .userInteractive)
    private var weightingFilter: AudioWeightingFilter?
    private var leqCalculator = LeqCalculator()
    private var slidingAverage = SlidingAverage(windowSize: 8)
    private var sessionSumDB: Float = 0
    private var filteredScratch: [Float] = []
    private var sampleCount = 0
    private var lastUIUpdate = Date.distantPast
    private var cachedCalibrationOffset = WatchCalibrationStore.totalOffset
    private var sessionMinDB: Float = 120

    private let uiInterval: TimeInterval = 0.25

    private var effectiveWeighting: WeightingType {
        isHighSensitivityMode ? .z : WatchCalibrationStore.weightingType
    }

    var weightingBadge: String {
        isHighSensitivityMode ? "dBZ" : "dBA"
    }

    var riskLevel: NoiseRiskLevel {
        .from(db: currentDB, highSensitivity: isHighSensitivityMode)
    }

    func requestPermissionAndStart(runtime: WatchExtendedRuntimeManager) async {
        permissionGranted = await WatchAudioSessionManager.requestPermission()
        guard permissionGranted else {
            errorMessage = WatchAudioSessionError.permissionDenied.localizedDescription
            return
        }
        startMonitoring(runtime: runtime)
    }

    func startMonitoring(runtime: WatchExtendedRuntimeManager) {
        guard !isMonitoring else { return }
        errorMessage = nil
        runtimeNotice = nil

        do {
            try WatchAudioSessionManager.configureForMeasurement()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        resetStatistics()
        cachedCalibrationOffset = WatchCalibrationStore.totalOffset
        setupAudioPipeline()
        runtime.start()

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isMonitoring = true
        } catch {
            runtime.stop()
            errorMessage = WatchL10n.engineStartFailed(error.localizedDescription)
        }
    }

    func stopMonitoring(runtime: WatchExtendedRuntimeManager) {
        guard isMonitoring else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        WatchAudioSessionManager.deactivate()
        runtime.stop()
        isMonitoring = false
        minDB = 0
        sessionMinDB = 120
        WatchSnapshotStore.save(
            WatchMonitorSnapshot(
                currentDB: 0,
                maxDB: maxDB,
                isMonitoring: false,
                isHighSensitivity: isHighSensitivityMode,
                updatedAt: Date()
            )
        )
    }

    func handleRuntimeInvalidation(_ message: String, runtime: WatchExtendedRuntimeManager) {
        runtimeNotice = message
        if isMonitoring {
            stopMonitoring(runtime: runtime)
        }
    }

    private func restartPipeline() {
        guard isMonitoring else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        setupAudioPipeline()
    }

    private func resetStatistics() {
        currentDB = 0
        maxDB = 0
        minDB = 0
        sessionMinDB = 120
        averageDB = 0
        leq = 0
        leqCalculator.reset()
        slidingAverage = SlidingAverage(windowSize: 8)
        sampleCount = 0
        sessionSumDB = 0
    }

    private func setupAudioPipeline() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let weighting = effectiveWeighting

        weightingFilter = AudioWeightingFilter(type: weighting, sampleRate: sampleRate)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: SPLCalculator.tapBufferSize,
            format: format
        ) { [weak self] buffer, _ in
            self?.processingQueue.async {
                self?.processBuffer(buffer)
            }
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
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
        var smoothed: Float = 0

        filteredScratch.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            let measurement = SPLCalculator.spl(
                from: base,
                frameLength: frameLength,
                calibrationOffset: offset
            )
            dbSPL = measurement.dbSPL
            smoothed = slidingAverage.add(dbSPL)
        }

        leqCalculator.addSample(dbSPL: dbSPL)
        sampleCount += 1
        sessionSumDB += smoothed

        let now = Date()
        guard now.timeIntervalSince(lastUIUpdate) >= uiInterval else { return }
        lastUIUpdate = now

        let snapshotSmoothed = smoothed
        let snapshotLeq = leqCalculator.leq
        let snapshotMax = max(maxDB, snapshotSmoothed)
        sessionMinDB = min(sessionMinDB, snapshotSmoothed)
        let snapshotMin = sessionMinDB
        let snapshotAvg = sampleCount > 0 ? sessionSumDB / Float(sampleCount) : snapshotSmoothed

        Task { @MainActor in
            currentDB = snapshotSmoothed
            maxDB = snapshotMax
            minDB = snapshotMin
            averageDB = snapshotAvg
            leq = snapshotLeq
            WatchSnapshotStore.save(
                WatchMonitorSnapshot(
                    currentDB: snapshotSmoothed,
                    maxDB: snapshotMax,
                    isMonitoring: true,
                    isHighSensitivity: isHighSensitivityMode,
                    updatedAt: now
                )
            )
        }
    }
}
