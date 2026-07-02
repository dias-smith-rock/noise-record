import ActivityKit
import Foundation

struct NoiseMonitorAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var currentDecibel: Float
        var noiseLevelDescription: String
        var statusMessage: String
        var weightingLabel: String
        var waveformLevels: [Float]
    }

    /// User-facing measurement mode at session start (e.g. Standard / High Sensitivity).
    var measurementModeName: String
    /// Initial weighting badge shown in expanded UI (e.g. dBA / dBZ).
    var weightingBadge: String
    var isHighSensitivityMode: Bool
    var sessionStartedAt: Date
}

enum LiveActivityDeepLink {
    static let scheme = "decibelpro"
    static let monitorHost = "monitor"
    static let sleepReportHost = "sleep-report"
    static let sessionIDKey = "sleepSessionID"
    static var monitorURL: URL { URL(string: "\(scheme)://\(monitorHost)")! }

    static func sleepReportURL(sessionID: UUID) -> URL {
        URL(string: "\(scheme)://\(sleepReportHost)/\(sessionID.uuidString)")!
    }
}

enum LiveActivityStyle {
    static func decibelColorHex(for db: Float, highSensitivity: Bool) -> String {
        DecibelColorStyle.colorHex(for: db, highSensitivity: highSensitivity)
    }

    static func normalizedWaveformLevels(_ samples: [Float], fallbackDB: Float) -> [Float] {
        let source = samples.isEmpty ? [fallbackDB] : samples
        let recent = Array(source.suffix(5))
        let minValue = recent.min() ?? 0
        let maxValue = max(recent.max() ?? 1, minValue + 1)
        let span = max(maxValue - minValue, 1)
        var bars = recent.map { sample in
            max(0.12, min(1, (sample - minValue) / span))
        }
        while bars.count < 5 {
            bars.insert(0.12, at: 0)
        }
        if bars.count > 5 {
            bars = Array(bars.suffix(5))
        }
        return bars
    }
}
