import Foundation

/// Persisted Monitor tab / app-launch behaviour settings.
nonisolated enum MonitorSettingsStore {
    private static let autoStartMonitoringOnLaunchKey = "settings.autoStartMonitoringOnLaunch"

    /// When `true`, cold launch automatically starts noise monitoring after launch UI settles.
    static var autoStartMonitoringOnLaunch: Bool {
        get {
            guard UserDefaults.standard.object(forKey: autoStartMonitoringOnLaunchKey) != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: autoStartMonitoringOnLaunchKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoStartMonitoringOnLaunchKey) }
    }
}
