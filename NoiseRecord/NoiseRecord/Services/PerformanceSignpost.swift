import Foundation
import os

/// os_signpost helpers for Instruments (Points of Interest / os_log).
nonisolated enum PerformanceSignpost {
    private static let log = OSLog(subsystem: "com.goodcraft.NoiseRecord", category: "Performance")

    enum Interval: String {
        case processBuffer = "processBuffer"
        case publishUI = "publishUI"
        case processVideoSample = "processVideoSample"
        case drawWatermark = "drawWatermark"
        case tabBarIconApply = "tabBarIconApply"
        case persistMeasurement = "persistMeasurement"
        case launchSwiftDataInit = "launchSwiftDataInit"
    }

    static func begin(_ interval: Interval) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Interval", signpostID: id, "%{public}s", interval.rawValue)
        return id
    }

    static func end(_ interval: Interval, _ id: OSSignpostID) {
        os_signpost(.end, log: log, name: "Interval", signpostID: id, "%{public}s", interval.rawValue)
    }

    static func event(_ interval: Interval) {
        os_signpost(.event, log: log, name: "Event", "%{public}s", interval.rawValue)
    }

    static func launchEvent(_ milestone: String) {
        os_signpost(.event, log: log, name: "Launch", "%{public}s", milestone)
    }
}
