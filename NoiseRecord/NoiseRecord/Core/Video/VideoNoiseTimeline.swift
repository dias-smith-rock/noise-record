import Foundation

struct VideoNoiseSample: Codable, Sendable, Equatable {
    let time: Double
    let decibel: Float
}

enum VideoNoiseTimelineSource: String, Codable, Sendable {
    case live
    case offline
}

struct VideoNoiseTimeline: Codable, Sendable {
    static let currentVersion = 2

    let version: Int
    let weighting: String
    let samples: [VideoNoiseSample]
    let source: VideoNoiseTimelineSource?
    let normalized: Bool?

    init(
        weighting: String,
        samples: [VideoNoiseSample],
        source: VideoNoiseTimelineSource = .offline,
        normalized: Bool = true
    ) {
        self.version = Self.currentVersion
        self.weighting = weighting
        self.samples = samples
        self.source = source
        self.normalized = normalized
    }

    /// v1 live-recorded sidecars may have misaligned timestamps relative to playback.
    var isValidForPlaybackAlignment: Bool {
        version >= Self.currentVersion && (normalized ?? false)
    }

    func decibel(at playbackTime: Double) -> Float? {
        guard let first = samples.first else { return nil }
        if playbackTime <= first.time { return first.decibel }
        guard let last = samples.last else { return nil }
        if playbackTime >= last.time { return last.decibel }

        var lower = 0
        var upper = samples.count - 1
        while lower + 1 < upper {
            let mid = (lower + upper) / 2
            if samples[mid].time <= playbackTime {
                lower = mid
            } else {
                upper = mid
            }
        }

        let start = samples[lower]
        let end = samples[upper]
        let span = end.time - start.time
        guard span > 0 else { return start.decibel }
        let progress = (playbackTime - start.time) / span
        return start.decibel + Float(progress) * (end.decibel - start.decibel)
    }

    var timelineDuration: TimeInterval {
        samples.last?.time ?? 0
    }

    func normalized(to targetDuration: TimeInterval, source: VideoNoiseTimelineSource) -> VideoNoiseTimeline? {
        guard targetDuration > 0, let last = samples.last, last.time > 0 else { return nil }
        let scale = targetDuration / last.time
        guard abs(scale - 1) > 0.001 else {
            return VideoNoiseTimeline(
                weighting: weighting,
                samples: samples,
                source: source,
                normalized: true
            )
        }

        let scaled = samples.map {
            VideoNoiseSample(time: $0.time * scale, decibel: $0.decibel)
        }
        return VideoNoiseTimeline(
            weighting: weighting,
            samples: scaled,
            source: source,
            normalized: true
        )
    }
}
