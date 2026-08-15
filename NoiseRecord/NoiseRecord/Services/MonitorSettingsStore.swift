import Foundation

/// Persisted Monitor tab / app-launch behaviour settings.
nonisolated enum MonitorSettingsStore {
    private static let autoStartMonitoringOnLaunchKey = "settings.autoStartMonitoringOnLaunch"

    /// When `true`, cold launch automatically starts noise monitoring after launch UI settles.
    /// Defaults to `false` — monitoring starts only when the user explicitly begins monitor or video capture.
    static var autoStartMonitoringOnLaunch: Bool {
        get {
            guard UserDefaults.standard.object(forKey: autoStartMonitoringOnLaunchKey) != nil else {
                return false
            }
            return UserDefaults.standard.bool(forKey: autoStartMonitoringOnLaunchKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoStartMonitoringOnLaunchKey) }
    }
}
