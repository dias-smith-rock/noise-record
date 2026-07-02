import Foundation
import UserNotifications

enum SleepNotificationScheduler {
    private static let wakeReportIdentifier = "sleep.wakeReport"
    private static let immediateReportPrefix = "sleep.report."

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func scheduleDailyWakeReminder() async {
        guard SleepMonitorSettingsStore.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [wakeReportIdentifier])

        let content = UNMutableNotificationContent()
        content.title = L10n.sleepNotificationWakeTitle
        content.body = L10n.sleepNotificationWakeBody
        content.sound = .default

        var components = SleepMonitorSettingsStore.wakeTimeComponents
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: wakeReportIdentifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func deliverImmediateReport(
        sessionID: UUID,
        summary: String
    ) async {
        guard SleepMonitorSettingsStore.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = L10n.sleepNotificationReportTitle
        content.body = summary
        content.sound = .default
        content.userInfo = [
            LiveActivityDeepLink.sessionIDKey: sessionID.uuidString,
        ]

        let request = UNNotificationRequest(
            identifier: immediateReportPrefix + sessionID.uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
