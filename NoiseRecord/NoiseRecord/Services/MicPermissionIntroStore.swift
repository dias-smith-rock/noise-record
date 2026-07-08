import Foundation

nonisolated enum MicPermissionIntroStore {
    private static let hasSeenIntroKey = "permission.microphoneIntro.seen"

    static var hasSeenIntro: Bool {
        UserDefaults.standard.bool(forKey: hasSeenIntroKey)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenIntroKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: hasSeenIntroKey)
    }
    #endif
}
