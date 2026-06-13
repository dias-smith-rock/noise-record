import Foundation

struct VideoNoiseSample: Codable, Sendable, Equatable {
    let time: Double
    let decibel: Float
}

struct VideoNoiseTimeline: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let weighting: String
    let samples: [VideoNoiseSample]

    init(weighting: String, samples: [VideoNoiseSample]) {
        self.version = Self.currentVersion
        self.weighting = weighting
        self.samples = samples
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
}
