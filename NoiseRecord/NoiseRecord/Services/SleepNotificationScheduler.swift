import Foundation
import UserNotifications

enum SleepNotificationScheduler {
    private static let wakeReportIdentifier = "sleep.wakeReport"
    private static let bedtimeReminderIdentifier = "sleep.bedtimeReminder"
    private static let overnightActivationIdentifier = "sleep.overnightActivation"
    private static let overnightActivationScheduledKey = "sleep.overnightActivationScheduled"
    private static let immediateReportPrefix = "sleep.report."
    private static let bedtimeReminderHour = 21
    private static let bedtimeReminderMinute = 0

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

    static func scheduleDailyReminders() async {
        let center = UNUserNotificationCenter.current()
        guard SleepMonitorSettingsStore.notificationsEnabled else {
            center.removePendingNotificationRequests(
                withIdentifiers: [wakeReportIdentifier, bedtimeReminderIdentifier]
            )
            return
        }

        await scheduleDailyWakeReminder(center: center)
        await scheduleDailyBedtimeReminder(center: center)
    }

    private static func scheduleDailyWakeReminder(center: UNUserNotificationCenter) async {
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

    private static func scheduleDailyBedtimeReminder(center: UNUserNotificationCenter) async {
        center.removePendingNotificationRequests(withIdentifiers: [bedtimeReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = L10n.sleepNotificationBedtimeTitle
        content.body = L10n.sleepNotificationBedtimeBody
        content.sound = .default

        var components = DateComponents(
            hour: bedtimeReminderHour,
            minute: bedtimeReminderMinute,
            second: 0
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: bedtimeReminderIdentifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    /// 首次完成 ≥2 分钟监测后，次日 21:00 推送一次夜间监测引导。
    static func scheduleOvernightActivationReminderIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: overnightActivationScheduledKey) else { return }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [overnightActivationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = L10n.sleepNotificationOvernightActivationTitle
        content.body = L10n.sleepNotificationOvernightActivationBody
        content.sound = .default

        guard let tomorrowNinePM = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: bedtimeReminderHour, minute: bedtimeReminderMinute),
            matchingPolicy: .nextTime
        ) else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: tomorrowNinePM
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: overnightActivationIdentifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
        UserDefaults.standard.set(true, forKey: overnightActivationScheduledKey)
        AppTelemetry.logProductEvent("sleep_overnight_activation_scheduled")
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
