import Foundation

nonisolated enum AppOnboardingStore {
    private static let hasCompletedKey = "onboarding.app.completed"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: hasCompletedKey)
    }
    #endif
}
