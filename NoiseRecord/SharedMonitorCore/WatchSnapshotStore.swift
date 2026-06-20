import Foundation

/// Shared App Group snapshot for Watch complications and glanceable widgets (phase 2).
struct WatchMonitorSnapshot: Codable, Sendable {
    var currentDB: Float
    var maxDB: Float
    var isMonitoring: Bool
    var isHighSensitivity: Bool
    var updatedAt: Date
}

enum WatchSnapshotStore {
    private static let key = "watch.monitor.snapshot"

    static func save(_ snapshot: WatchMonitorSnapshot) {
        guard let defaults = UserDefaults(suiteName: WatchCalibrationStore.appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WatchMonitorSnapshot? {
        guard let defaults = UserDefaults(suiteName: WatchCalibrationStore.appGroupID),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WatchMonitorSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
