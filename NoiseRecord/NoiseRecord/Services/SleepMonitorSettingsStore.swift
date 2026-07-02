import Foundation

enum SleepMonitorSettingsStore {
    private static let wakeHourKey = "sleepMonitor.wakeHour"
    private static let wakeMinuteKey = "sleepMonitor.wakeMinute"
    private static let notificationsEnabledKey = "sleepMonitor.notificationsEnabled"
    private static let pendingReportSessionIDKey = "sleepMonitor.pendingReportSessionID"

    static var wakeHour: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: wakeHourKey) as? Int
            return stored ?? 7
        }
        set { UserDefaults.standard.set(newValue, forKey: wakeHourKey) }
    }

    static var wakeMinute: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: wakeMinuteKey) as? Int
            return stored ?? 0
        }
        set { UserDefaults.standard.set(newValue, forKey: wakeMinuteKey) }
    }

    static var notificationsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: notificationsEnabledKey) }
    }

    static var pendingReportSessionID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: pendingReportSessionIDKey) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: pendingReportSessionIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingReportSessionIDKey)
            }
        }
    }

    static var wakeTimeComponents: DateComponents {
        DateComponents(hour: wakeHour, minute: wakeMinute)
    }

    static var defaultWakeDate: Date {
        Calendar.current.date(from: wakeTimeComponents) ?? Date()
    }
}
