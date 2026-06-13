import Foundation

/// Tracks whether the Files tab should show an unread indicator.
nonisolated enum FilesTabBadgeStore {
    static let didChangeNotification = Notification.Name("FilesTabBadgeStore.didChange")

    private static let pendingKey = "files.tabBadgePending"

    static var isPending: Bool {
        get { UserDefaults.standard.bool(forKey: pendingKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: pendingKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func markPending() {
        isPending = true
    }

    static func clear() {
        isPending = false
    }
}
