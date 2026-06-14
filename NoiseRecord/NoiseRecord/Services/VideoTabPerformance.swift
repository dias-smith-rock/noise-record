import FirebaseCore
import Foundation
import os

/// Video tab activation milestones for profiling. Logging only — does not alter app flow.
nonisolated enum VideoTabPerformance {
    enum Step: String {
        case tabSelected
        case viewAppear
        case taskActiveBegin
        case audioSessionDone
        case captureConfigureDone
        case captureStartRequested
        case captureSessionRunning
        case uiReady
        case previewReady
        case locationPermissionRequested
        case configureComplete
        case configureFailed
        case syncNoiseDone
        case restoreMonitoringDone
        case taskActiveComplete
        case previewViewCreated
        case taskInactiveBegin
        case teardownDone
        case taskInactiveComplete
    }

    enum Interval: String {
        case audioSession = "videoTabAudioSession"
        case captureConfigure = "videoTabCaptureConfigure"
        case configureTotal = "videoTabConfigureTotal"
        case teardown = "videoTabTeardown"
    }

    private static let log = OSLog(subsystem: "com.goodcraft.NoiseRecord", category: "VideoTab")
    private static var sessionStart = CFAbsoluteTimeGetCurrent()
    private static let lock = NSLock()

    static func beginSession() {
        lock.lock()
        sessionStart = CFAbsoluteTimeGetCurrent()
        lock.unlock()

        #if DEBUG
        print("[VideoTab] --- session begin ---")
        #endif
    }

    static func mark(_ step: Step) {
        let elapsedMs = elapsedMsSinceSession()

        #if DEBUG
        print("[VideoTab] \(step.rawValue) @ +\(elapsedMs)ms")
        #endif

        if FirebaseApp.app() != nil {
            AppTelemetry.logEvent(
                "video_tab_milestone",
                parameters: [
                    "step": step.rawValue,
                    "elapsed_ms": elapsedMs,
                ]
            )
        }

        os_signpost(.event, log: log, name: "Milestone", "%{public}s +%{public}dms", step.rawValue, elapsedMs)
    }

    static func begin(_ interval: Interval) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Interval", signpostID: id, "%{public}s", interval.rawValue)
        return id
    }

    static func end(_ interval: Interval, _ id: OSSignpostID) {
        let elapsedMs = elapsedMsSinceSession()
        os_signpost(.end, log: log, name: "Interval", signpostID: id, "%{public}s +%{public}dms", interval.rawValue, elapsedMs)
    }

    private static func elapsedMsSinceSession() -> Int {
        lock.lock()
        let start = sessionStart
        lock.unlock()
        return Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
    }
}
