import Foundation

nonisolated enum WidgetSnapshotStore {
    private static let snapshotKey = "widget.monitoringSnapshot"
    private static let pendingActionKey = "widget.pendingAction"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetAppGroup.identifier)
    }

    static func save(_ snapshot: WidgetMonitoringSnapshot) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        if let url = sharedSnapshotFileURL {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load() -> WidgetMonitoringSnapshot? {
        if let defaults,
           let data = defaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(WidgetMonitoringSnapshot.self, from: data) {
            return snapshot
        }
        guard let url = sharedSnapshotFileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetMonitoringSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    private static var sharedSnapshotFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetAppGroup.identifier)?
            .appendingPathComponent("widget-monitoring-snapshot.json")
    }

    static func clear() {
        defaults?.removeObject(forKey: snapshotKey)
    }

    static var pendingAction: WidgetPendingAction? {
        get {
            guard let raw = defaults?.string(forKey: pendingActionKey) else { return nil }
            return WidgetPendingAction(rawValue: raw)
        }
        set {
            guard let defaults else { return }
            if let newValue {
                defaults.set(newValue.rawValue, forKey: pendingActionKey)
            } else {
                defaults.removeObject(forKey: pendingActionKey)
            }
        }
    }

    static func postPendingActionNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(WidgetDarwinNotifications.pendingActionName as CFString),
            nil,
            nil,
            true
        )
    }
}
