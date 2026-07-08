import Foundation

struct MonitorSessionSummary: Equatable {
    let startedAt: Date
    let endedAt: Date
    let maxDB: Float
    let averageDB: Float

    var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

/// 监测漏斗埋点：首屏读数、会话时长、价值时刻 Paywall。
@MainActor
enum MonitoringFunnelTracker {
    private static let minimumMeaningfulDB: Float = 1
    private static let valueMomentDuration: TimeInterval = 30

    private static var processLaunchTime = Date()
    private static var monitoringStartedAt: Date?
    private static var hasLoggedFirstDBReading = false
    private static var hasTriggeredValueMomentPaywall = false

    static func resetProcessLaunchClock() {
        processLaunchTime = Date()
        hasLoggedFirstDBReading = false
    }

    static func noteMonitoringStarted(at date: Date = Date()) {
        monitoringStartedAt = date
    }

    static func noteMonitoringStopped(engine: NoiseMonitorEngine) -> MonitorSessionSummary? {
        guard let startedAt = monitoringStartedAt else { return nil }
        let summary = MonitorSessionSummary(
            startedAt: startedAt,
            endedAt: Date(),
            maxDB: engine.maxDB,
            averageDB: engine.averageDB
        )
        monitoringStartedAt = nil
        logSessionDuration(summary)
        return summary
    }

    static func observeReading(currentDB: Float, isMonitoring: Bool) {
        guard isMonitoring else { return }

        if !hasLoggedFirstDBReading, currentDB >= minimumMeaningfulDB {
            hasLoggedFirstDBReading = true
            let elapsedMs = Int(Date().timeIntervalSince(processLaunchTime) * 1000)
            AppTelemetry.logProductEvent(
                "time_to_first_db",
                parameters: [
                    "elapsed_ms": String(elapsedMs),
                    "db": String(format: "%.1f", currentDB),
                ]
            )
        }

        guard LaunchExperienceStore.shouldDeferLaunchPaywallOnColdStart else { return }
        guard !hasTriggeredValueMomentPaywall else { return }
        guard let startedAt = monitoringStartedAt else { return }
        guard currentDB >= minimumMeaningfulDB else { return }
        guard Date().timeIntervalSince(startedAt) >= valueMomentDuration else { return }

        hasTriggeredValueMomentPaywall = true
        LaunchExperienceCoordinator.presentDeferredLaunchPaywall(trigger: "monitoring_30s")
    }

    private static func logSessionDuration(_ summary: MonitorSessionSummary) {
        let duration = summary.duration
        let bucket: String
        switch duration {
        case ..<30:
            bucket = "lt_30s"
        case ..<120:
            bucket = "30s_2m"
        case ..<600:
            bucket = "2m_10m"
        default:
            bucket = "gte_10m"
        }

        AppTelemetry.logProductEvent(
            "monitor_session_duration",
            parameters: [
                "bucket": bucket,
                "seconds": String(Int(duration.rounded())),
                "max_db": String(format: "%.0f", summary.maxDB),
                "avg_db": String(format: "%.0f", summary.averageDB),
            ]
        )
    }
}
