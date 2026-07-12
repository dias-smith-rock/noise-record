import Foundation
import UserNotifications

enum SleepNotificationAction: Equatable {
    case openTodayReport
    case openReport(UUID)
    case startSleepMonitoring
}

enum SleepNotificationRouter {
    static let actionKey = "action"
    static let actionOpenTodayReport = "openTodayReport"
    static let actionOpenReport = "openReport"
    static let actionStartSleepMonitoring = "startSleepMonitoring"

    static let wakeReportIdentifier = "sleep.wakeReport"
    static let bedtimeReminderIdentifier = "sleep.bedtimeReminder"
    static let overnightActivationIdentifier = "sleep.overnightActivation"
    static let immediateReportPrefix = "sleep.report."

    static let actionPendingNotification = Notification.Name("SleepNotificationRouter.actionPending")
    static let sleepMonitoringStartedFromNotification = Notification.Name(
        "SleepNotificationRouter.sleepMonitoringStarted"
    )

    private static let lock = NSLock()
    private static var _pendingAction: SleepNotificationAction?

    static var pendingAction: SleepNotificationAction? {
        lock.withLock { _pendingAction }
    }

    @discardableResult
    static func handle(response: UNNotificationResponse) -> SleepNotificationAction? {
        guard let action = parse(response: response) else { return nil }

        lock.withLock {
            _pendingAction = action
        }

        AppTelemetry.logProductEvent(
            "sleep_notification_tapped",
            parameters: [
                "action": telemetryActionName(for: action),
                "identifier": response.notification.request.identifier,
            ]
        )

        NotificationCenter.default.post(name: actionPendingNotification, object: nil)
        return action
    }

    static func consumePendingAction() -> SleepNotificationAction? {
        lock.withLock {
            defer { _pendingAction = nil }
            return _pendingAction
        }
    }

    #if DEBUG
    static func resetForTesting() {
        lock.withLock {
            _pendingAction = nil
        }
    }

    static func storePendingActionForTesting(_ action: SleepNotificationAction) {
        lock.withLock {
            _pendingAction = action
        }
    }
    #endif

    static func parse(response: UNNotificationResponse) -> SleepNotificationAction? {
        parse(
            identifier: response.notification.request.identifier,
            userInfo: response.notification.request.content.userInfo
        )
    }

    static func parse(identifier: String, userInfo: [AnyHashable: Any]) -> SleepNotificationAction? {
        if let sessionID = sessionID(from: userInfo) {
            return .openReport(sessionID)
        }

        if identifier.hasPrefix(immediateReportPrefix),
           let suffix = identifier.split(separator: ".").last,
           let sessionID = UUID(uuidString: String(suffix)) {
            return .openReport(sessionID)
        }

        if let action = userInfo[actionKey] as? String {
            switch action {
            case actionOpenTodayReport:
                return .openTodayReport
            case actionStartSleepMonitoring:
                return .startSleepMonitoring
            default:
                break
            }
        }

        switch identifier {
        case wakeReportIdentifier:
            return .openTodayReport
        case bedtimeReminderIdentifier, overnightActivationIdentifier:
            return .startSleepMonitoring
        default:
            return nil
        }
    }

    private static func sessionID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let raw = userInfo[LiveActivityDeepLink.sessionIDKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    private static func telemetryActionName(for action: SleepNotificationAction) -> String {
        switch action {
        case .openTodayReport:
            "open_today_report"
        case .openReport:
            "open_report"
        case .startSleepMonitoring:
            "start_sleep_monitoring"
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
