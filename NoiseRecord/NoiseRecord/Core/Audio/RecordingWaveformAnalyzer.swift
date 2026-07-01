import AVFoundation
import Foundation

enum RecordingWaveformAnalyzer {
    static let sampleInterval: Double = 0.1

    static func loadCachedTimeline(for fileURL: URL, alternateURLs: [URL] = []) -> VideoNoiseTimeline? {
        guard let cached = VideoNoiseTimelineStore.load(for: fileURL, alternateURLs: alternateURLs),
              isCacheValidForPlayback(cached) else { return nil }
        return cached
    }

    /// List thumbnails: show any existing sidecar without triggering analysis.
    static func loadCachedTimelineForThumbnail(
        for fileURL: URL,
        alternateURLs: [URL] = []
    ) -> VideoNoiseTimeline? {
        guard let cached = VideoNoiseTimelineStore.load(for: fileURL, alternateURLs: alternateURLs),
              !cached.samples.isEmpty else { return nil }
        return cached
    }

    static func loadCachedDecibels(for fileURL: URL, alternateURLs: [URL] = []) -> [Float]? {
        loadCachedTimelineForThumbnail(for: fileURL, alternateURLs: alternateURLs)?
            .samples.map(\.decibel)
    }

    static func loadOrAnalyze(
        fileURL: URL,
        weighting: WeightingType = DeviceCalibrationStore.weightingType
    ) async throws -> VideoNoiseTimeline {
        if let cached = VideoNoiseTimelineStore.load(for: fileURL),
           isCacheValidForPlayback(cached) {
            return cached
        }

        let analysisWeighting = isPreWeightedAudio(fileURL) ? WeightingType.z : weighting
        let timeline = try await analyze(fileURL: fileURL, weighting: analysisWeighting)
        try VideoNoiseTimelineStore.save(timeline, for: fileURL)
        return timeline
    }

    /// Playback overlay: prefer live recording sidecar; fall back to embedded-audio analysis.
    static func playbackTimeline(for fileURL: URL) async throws -> VideoNoiseTimeline {
        let fileDuration = await mediaDuration(for: fileURL)

        if var cached = VideoNoiseTimelineStore.load(for: fileURL), !cached.samples.isEmpty {
            if fileDuration > 0,
               let normalized = cached.normalized(to: fileDuration, source: cached.source ?? .live) {
                cached = normalized
            }
            if hasMeaningfulVariation(cached) {
                return cached
            }
        }

        let weighting = DeviceCalibrationStore.weightingType
        var timeline = try await analyze(fileURL: fileURL, weighting: weighting)
        if fileDuration > 0, let normalized = timeline.normalized(to: fileDuration, source: .offline) {
            timeline = normalized
        }
        guard hasMeaningfulVariation(timeline) else {
            throw AnalysisError.noAudioTrack
        }

        if let existing = VideoNoiseTimelineStore.load(for: fileURL),
           existing.source == .live,
           hasMeaningfulVariation(existing) {
            if fileDuration > 0,
               let normalized = existing.normalized(to: fileDuration, source: .live) {
                return normalized
            }
            return existing
        }

        try VideoNoiseTimelineStore.save(timeline, for: fileURL)
        return timeline
    }

    static func mediaDuration(for fileURL: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: fileURL)
        if let duration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 {
                return seconds
            }
        }
        return 0
    }

    private static func isPreWeightedAudio(_ fileURL: URL) -> Bool {
        fileURL.pathExtension.lowercased() == "m4a"
    }

    private static func isVideoContainer(_ fileURL: URL) -> Bool {
        switch fileURL.pathExtension.lowercased() {
        case "mp4", "mov", "m4v":
            return true
        default:
            return false
        }
    }

    private static func isCacheValidForPlayback(_ timeline: VideoNoiseTimeline) -> Bool {
        guard timeline.isValidForPlaybackAlignment, !timeline.samples.isEmpty else { return false }
        return hasMeaningfulVariation(timeline)
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
        if isVideoContainer(fileURL) {
            if let timeline = try? analyzeVideoContainerSynchronously(fileURL: fileURL, weighting: weighting) {
                return timeline
            }
        }

        do {
            return try analyzeAudioFileSynchronously(fileURL: fileURL, weighting: weighting)
        } catch {
            if isVideoContainer(fileURL) {
                throw error
            }
            if let timeline = try? analyzeVideoContainerSynchronously(fileURL: fileURL, weighting: weighting) {
                return timeline
            }
            throw error
        }
    }

    private static func analyzeAudioFileSynchronously(
        fileURL: URL,
        weighting: WeightingType
    ) throws -> VideoNoiseTimeline {
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

            let monoSamples = monoMix(
                channelData: channelData,
                channelCount: channelCount,
                frameLength: frameLength,
                scratch: &monoScratch
            )

            processMonoSamples(
                monoSamples,
                sampleRate: sampleRate,
                weightingFilter: weightingFilter,
                calibrationOffset: calibrationOffset,
                samplesPerWindow: samplesPerWindow,
                windowSamples: &windowSamples,
                nextSampleTime: &nextSampleTime,
                into: &samples
            )
        }

        flushWindow(
            windowSamples,
            calibrationOffset: calibrationOffset,
            nextSampleTime: nextSampleTime,
            into: &samples
        )

        guard !samples.isEmpty else { throw AnalysisError.noAudioTrack }

        let fileDuration = Double(file.length) / sampleRate
        return makeTimeline(
            samples: samples,
            weighting: weighting,
            fileDuration: fileDuration
        )
    }

    private static func analyzeVideoContainerSynchronously(
        fileURL: URL,
        weighting: WeightingType
    ) throws -> VideoNoiseTimeline {
        let asset = AVURLAsset(url: fileURL)
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard let track = audioTracks.first else {
            throw AnalysisError.noAudioTrack
        }

        var sampleRate = 44_100.0
        var channelCount = 1
        if let formatDescription = track.formatDescriptions.first {
            let audioDescription = formatDescription as! CMFormatDescription
            if let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioDescription) {
                let asbd = streamDescription.pointee
                if asbd.mSampleRate > 0 {
                    sampleRate = asbd.mSampleRate
                }
                channelCount = max(1, Int(asbd.mChannelsPerFrame))
            }
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw AnalysisError.readerSetupFailed
        }
        reader.add(output)
        guard reader.startReading() else {
            throw AnalysisError.readerSetupFailed
        }

        let weightingFilter = AudioWeightingFilter(type: weighting, sampleRate: sampleRate)
        let calibrationOffset = DeviceCalibrationStore.totalOffset
        let samplesPerWindow = max(1, Int(sampleRate * sampleInterval))

        var samples: [VideoNoiseSample] = []
        var windowSamples: [Float] = []
        var nextSampleTime = 0.0

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            guard length > 0 else { continue }

            var data = Data(count: length)
            let copyStatus = data.withUnsafeMutableBytes { pointer in
                guard let baseAddress = pointer.baseAddress else { return kCMBlockBufferBadLengthParameterErr }
                return CMBlockBufferCopyDataBytes(
                    blockBuffer,
                    atOffset: 0,
                    dataLength: length,
                    destination: baseAddress
                )
            }
            guard copyStatus == noErr else { continue }

            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
               let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                let asbd = streamDescription.pointee
                if asbd.mSampleRate > 0 {
                    sampleRate = asbd.mSampleRate
                }
                channelCount = max(1, Int(asbd.mChannelsPerFrame))
            }

            let frameLength = length / (channelCount * MemoryLayout<Float>.size)
            guard frameLength > 0 else { continue }

            let monoSamples: [Float] = data.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.bindMemory(to: Float.self).baseAddress else { return [] }
                if channelCount == 1 {
                    return Array(UnsafeBufferPointer(start: base, count: frameLength))
                }

                var mono = [Float](repeating: 0, count: frameLength)
                for frameIndex in 0..<frameLength {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += base[frameIndex * channelCount + channel]
                    }
                    mono[frameIndex] = sum / Float(channelCount)
                }
                return mono
            }

            processMonoSamples(
                monoSamples,
                sampleRate: sampleRate,
                weightingFilter: weightingFilter,
                calibrationOffset: calibrationOffset,
                samplesPerWindow: samplesPerWindow,
                windowSamples: &windowSamples,
                nextSampleTime: &nextSampleTime,
                into: &samples
            )
        }

        if reader.status == .failed {
            throw reader.error ?? AnalysisError.readerSetupFailed
        }

        flushWindow(
            windowSamples,
            calibrationOffset: calibrationOffset,
            nextSampleTime: nextSampleTime,
            into: &samples
        )

        guard !samples.isEmpty else { throw AnalysisError.noAudioTrack }

        let assetDuration = CMTimeGetSeconds(asset.duration)
        let fileDuration = assetDuration.isFinite && assetDuration > 0 ? assetDuration : nextSampleTime
        return makeTimeline(
            samples: samples,
            weighting: weighting,
            fileDuration: fileDuration
        )
    }

    private static func monoMix(
        channelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channelCount: Int,
        frameLength: Int,
        scratch: inout [Float]
    ) -> [Float] {
        if channelCount == 1 {
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        }

        if scratch.count < frameLength {
            scratch = [Float](repeating: 0, count: frameLength)
        }
        for index in 0..<frameLength {
            scratch[index] = 0
        }
        for channel in 0..<channelCount {
            let channelPointer = channelData[channel]
            for index in 0..<frameLength {
                scratch[index] += channelPointer[index]
            }
        }
        let scale = 1 / Float(channelCount)
        for index in 0..<frameLength {
            scratch[index] *= scale
        }
        return Array(scratch.prefix(frameLength))
    }

    private static func processMonoSamples(
        _ monoSamples: [Float],
        sampleRate: Double,
        weightingFilter: AudioWeightingFilter,
        calibrationOffset: Float,
        samplesPerWindow: Int,
        windowSamples: inout [Float],
        nextSampleTime: inout Double,
        into samples: inout [VideoNoiseSample]
    ) {
        guard !monoSamples.isEmpty else { return }

        var weighted = [Float](repeating: 0, count: monoSamples.count)
        monoSamples.withUnsafeBufferPointer { monoBuffer in
            guard let monoBase = monoBuffer.baseAddress else { return }
            weightingFilter.process(
                input: monoBase,
                output: &weighted,
                frameLength: monoSamples.count
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

    private static func flushWindow(
        _ windowSamples: [Float],
        calibrationOffset: Float,
        nextSampleTime: Double,
        into samples: inout [VideoNoiseSample]
    ) {
        guard !windowSamples.isEmpty else { return }
        appendWindow(
            windowSamples,
            at: nextSampleTime,
            calibrationOffset: calibrationOffset,
            into: &samples
        )
    }

    private static func makeTimeline(
        samples: [VideoNoiseSample],
        weighting: WeightingType,
        fileDuration: Double
    ) -> VideoNoiseTimeline {
        let weightingLabel = "dB\(weighting.rawValue)"
        let timeline = VideoNoiseTimeline(
            weighting: weightingLabel,
            samples: samples,
            source: .offline,
            normalized: true
        )
        return timeline.normalized(to: fileDuration, source: .offline) ?? timeline
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
