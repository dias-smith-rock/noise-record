import Foundation

nonisolated enum FullscreenLEDGuideStore {
    private static let hasSeenGuideKey = "guide.hasSeenFullscreenLED"

    static var hasSeenGuide: Bool {
        UserDefaults.standard.bool(forKey: hasSeenGuideKey)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenGuideKey)
    }
}
