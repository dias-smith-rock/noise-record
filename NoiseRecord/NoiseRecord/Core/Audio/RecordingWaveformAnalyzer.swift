import AVFoundation
import Foundation

enum RecordingWaveformAnalyzer {
    static let sampleInterval: Double = 0.1

    static func loadOrAnalyze(
        fileURL: URL,
        weighting: WeightingType = DeviceCalibrationStore.weightingType
    ) async throws -> VideoNoiseTimeline {
        if let cached = VideoNoiseTimelineStore.load(for: fileURL),
           hasMeaningfulVariation(cached) {
            return cached
        }

        let analysisWeighting = isPreWeightedAudio(fileURL) ? WeightingType.z : weighting
        let timeline = try await analyze(fileURL: fileURL, weighting: analysisWeighting)
        try VideoNoiseTimelineStore.save(timeline, for: fileURL)
        return timeline
    }

    private static func isPreWeightedAudio(_ fileURL: URL) -> Bool {
        fileURL.pathExtension.lowercased() == "m4a"
    }

    private static func hasMeaningfulVariation(_ timeline: VideoNoiseTimeline) -> Bool {
        guard let first = timeline.samples.first else { return false }
        guard timeline.samples.count > 1 else { return true }

        var minValue = first.decibel
        var maxValue = first.decibel
        for sample in timeline.samples.dropFirst() {
            minValue = min(minValue, sample.decibel)
            maxValue = max(maxValue, sample.decibel)
        }
        return maxValue - minValue > 0.5
    }

    private static func analyze(fileURL: URL, weighting: WeightingType) async throws -> VideoNoiseTimeline {
        try await Task.detached(priority: .userInitiated) {
            try analyzeSynchronously(fileURL: fileURL, weighting: weighting)
        }.value
    }

    private static func analyzeSynchronously(fileURL: URL, weighting: WeightingType) throws -> VideoNoiseTimeline {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        guard sampleRate > 0, channelCount > 0 else {
            throw AnalysisError.noAudioTrack
        }

        let weightingFilter = AudioWeightingFilter(type: weighting, sampleRate: sampleRate)
        let calibrationOffset = DeviceCalibrationStore.totalOffset

        let bufferFrameCapacity: AVAudioFrameCount = 8192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrameCapacity) else {
            throw AnalysisError.readerSetupFailed
        }

        var samples: [VideoNoiseSample] = []
        var windowSamples: [Float] = []
        let samplesPerWindow = max(1, Int(sampleRate * sampleInterval))
        var nextSampleTime = 0.0
        var monoScratch = [Float]()

        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: bufferFrameCapacity)
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0, let channelData = buffer.floatChannelData else { continue }

            let monoSamples: [Float]
            if channelCount == 1 {
                monoSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            } else {
                if monoScratch.count < frameLength {
                    monoScratch = [Float](repeating: 0, count: frameLength)
                }
                for index in 0..<frameLength {
                    monoScratch[index] = 0
                }
                for channel in 0..<channelCount {
                    let channelPointer = channelData[channel]
                    for index in 0..<frameLength {
                        monoScratch[index] += channelPointer[index]
                    }
                }
                let scale = 1 / Float(channelCount)
                for index in 0..<frameLength {
                    monoScratch[index] *= scale
                }
                monoSamples = Array(monoScratch.prefix(frameLength))
            }

            var weighted = [Float](repeating: 0, count: frameLength)
            monoSamples.withUnsafeBufferPointer { monoBuffer in
                guard let monoBase = monoBuffer.baseAddress else { return }
                weightingFilter.process(
                    input: monoBase,
                    output: &weighted,
                    frameLength: frameLength
                )
            }

            for sample in weighted {
                windowSamples.append(sample)
                if windowSamples.count >= samplesPerWindow {
                    appendWindow(
                        windowSamples,
                        at: nextSampleTime,
                        calibrationOffset: calibrationOffset,
                        into: &samples
                    )
                    windowSamples.removeAll(keepingCapacity: true)
                    nextSampleTime += sampleInterval
                }
            }
        }

        if !windowSamples.isEmpty {
            appendWindow(
                windowSamples,
                at: nextSampleTime,
                calibrationOffset: calibrationOffset,
                into: &samples
            )
        }

        guard !samples.isEmpty else { throw AnalysisError.noAudioTrack }

        let weightingLabel = "dB\(weighting.rawValue)"
        return VideoNoiseTimeline(weighting: weightingLabel, samples: samples)
    }

    private static func appendWindow(
        _ windowSamples: [Float],
        at time: Double,
        calibrationOffset: Float,
        into samples: inout [VideoNoiseSample]
    ) {
        guard !windowSamples.isEmpty else { return }
        let dbSPL: Float = windowSamples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return 0 }
            let rms = SPLCalculator.rms(from: base, frameLength: buffer.count)
            return SPLCalculator.spl(fromRMS: rms, calibrationOffset: calibrationOffset).dbSPL
        }
        samples.append(VideoNoiseSample(time: time, decibel: dbSPL))
    }

    enum AnalysisError: LocalizedError {
        case noAudioTrack
        case readerSetupFailed

        var errorDescription: String? {
            switch self {
            case .noAudioTrack: "No audio track found in file."
            case .readerSetupFailed: "Unable to decode audio for waveform analysis."
            }
        }
    }
}
