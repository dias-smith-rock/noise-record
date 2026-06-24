import FirebaseCore
import Foundation
import os

/// Mode switch milestones for profiling high-sensitivity ↔ standard transitions.
/// Logging only — does not alter app flow.
nonisolated enum ModeSwitchPerformance {
    enum Step: String {
        case uiTap
        case uiModeApplied
        case uiPostRender
        case engineDidSet
        case restartPipelineBegin
        case restartPipelineSkippedNotMonitoring
        case restartPipelineEnd
        case setupPipelineBegin
        case setupPipelineEnd
        case engineDidSetComplete
    }

    enum Interval: String {
        case restartPipelineTotal = "modeSwitchRestartPipeline"
        case removeTap = "modeSwitchRemoveTap"
        case setupPipelineTotal = "modeSwitchSetupPipeline"
        case weightingFilter = "modeSwitchWeightingFilter"
        case fftAnalyzer = "modeSwitchFFTAnalyzer"
        case voiceRecorderConfigure = "modeSwitchVoiceRecorder"
        case noiseClassifierSetup = "modeSwitchNoiseClassifier"
        case installTap = "modeSwitchInstallTap"
    }

    private struct SessionContext: Sendable {
        let fromMode: String
        let toMode: String
        let isMonitoring: Bool
        let source: String
    }

    private static let log = OSLog(subsystem: "com.goodcraft.NoiseRecord", category: "ModeSwitch")
    private static var sessionStart = CFAbsoluteTimeGetCurrent()
    private static var context: SessionContext?
    private static var isTracingPipelineSetup = false
    private static let lock = NSLock()

    static func beginSession(
        from: AcousticMeasurementMode,
        to: AcousticMeasurementMode,
        isMonitoring: Bool
    ) {
        lock.lock()
        sessionStart = CFAbsoluteTimeGetCurrent()
        context = SessionContext(
            fromMode: from.rawValue,
            toMode: to.rawValue,
            isMonitoring: isMonitoring,
            source: "ui"
        )
        isTracingPipelineSetup = false
        lock.unlock()

        #if DEBUG
        print("[ModeSwitch] --- session begin \(from.rawValue) → \(to.rawValue) monitoring=\(isMonitoring) ---")
        #endif

        mark(.uiTap)
    }

    static func noteEngineModeChange(
        fromHighSensitivity: Bool,
        toHighSensitivity: Bool,
        isMonitoring: Bool
    ) {
        lock.lock()
        if context == nil {
            sessionStart = CFAbsoluteTimeGetCurrent()
            context = SessionContext(
                fromMode: fromHighSensitivity ? AcousticMeasurementMode.highSensitivity.rawValue : AcousticMeasurementMode.standard.rawValue,
                toMode: toHighSensitivity ? AcousticMeasurementMode.highSensitivity.rawValue : AcousticMeasurementMode.standard.rawValue,
                isMonitoring: isMonitoring,
                source: "engine"
            )
            #if DEBUG
            print("[ModeSwitch] --- session begin (engine) ---")
            #endif
        }
        isTracingPipelineSetup = true
        lock.unlock()

        mark(.engineDidSet)
    }

    static func shouldTracePipelineSetup() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isTracingPipelineSetup
    }

    static func mark(_ step: Step) {
        let elapsedMs = elapsedMsSinceSession()
        let snapshot = sessionSnapshot()

        #if DEBUG
        if let snapshot {
            print(
                "[ModeSwitch] \(step.rawValue) @ +\(elapsedMs)ms"
                    + " \(snapshot.fromMode)→\(snapshot.toMode)"
                    + " monitoring=\(snapshot.isMonitoring)"
                    + " source=\(snapshot.source)"
            )
        } else {
            print("[ModeSwitch] \(step.rawValue) @ +\(elapsedMs)ms")
        }
        #endif

        guard FirebaseApp.app() != nil else { return }

        var parameters: [String: Any] = [
            "step": step.rawValue,
            "elapsed_ms": elapsedMs,
        ]
        if let snapshot {
            parameters["from_mode"] = snapshot.fromMode
            parameters["to_mode"] = snapshot.toMode
            parameters["is_monitoring"] = snapshot.isMonitoring ? 1 : 0
            parameters["source"] = snapshot.source
        }

        let eventParameters = parameters
        DispatchQueue.global(qos: .utility).async {
            AppTelemetry.logEvent("mode_switch_milestone", parameters: eventParameters)
        }
        os_signpost(.event, log: log, name: "Milestone", "%{public}s +%{public}dms", step.rawValue, elapsedMs)
    }

    static func schedulePostRenderMark() {
        DispatchQueue.main.async {
            mark(.uiPostRender)
            lock.lock()
            context = nil
            lock.unlock()
        }
    }

    static func begin(_ interval: Interval) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Interval", signpostID: id, "%{public}s", interval.rawValue)
        return id
    }

    static func end(_ interval: Interval, _ id: OSSignpostID) {
        let elapsedMs = elapsedMsSinceSession()
        os_signpost(.end, log: log, name: "Interval", signpostID: id, "%{public}s +%{public}dms", interval.rawValue, elapsedMs)

        guard shouldTracePipelineSetup(), FirebaseApp.app() != nil else { return }

        let snapshot = sessionSnapshot()
        var parameters: [String: Any] = [
            "interval": interval.rawValue,
            "elapsed_ms": elapsedMs,
        ]
        if let snapshot {
            parameters["from_mode"] = snapshot.fromMode
            parameters["to_mode"] = snapshot.toMode
            parameters["is_monitoring"] = snapshot.isMonitoring ? 1 : 0
        }

        let eventParameters = parameters
        DispatchQueue.global(qos: .utility).async {
            AppTelemetry.logEvent("mode_switch_interval", parameters: eventParameters)
        }
    }

    static func measure<T>(_ interval: Interval, when enabled: Bool, _ work: () -> T) -> T {
        guard enabled else { return work() }
        let id = begin(interval)
        defer { end(interval, id) }
        return work()
    }

    static func finishEngineModeChange() {
        mark(.engineDidSetComplete)

        lock.lock()
        isTracingPipelineSetup = false
        lock.unlock()
    }

    private static func elapsedMsSinceSession() -> Int {
        lock.lock()
        let start = sessionStart
        lock.unlock()
        return Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
    }

    private static func sessionSnapshot() -> SessionContext? {
        lock.lock()
        defer { lock.unlock() }
        return context
    }
}
