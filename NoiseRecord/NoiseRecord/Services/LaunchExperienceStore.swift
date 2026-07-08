import Foundation

/// 冷启动体验状态：首次启动先交付价值，再展示 Paywall。
nonisolated enum LaunchExperienceStore {
    private static let coldLaunchCountKey = "launch.coldLaunchCount"
    private static let hasShownLaunchPaywallKey = "launch.hasShownLaunchPaywall"

    static var coldLaunchCount: Int {
        max(0, UserDefaults.standard.integer(forKey: coldLaunchCountKey))
    }

    static var hasShownLaunchPaywall: Bool {
        UserDefaults.standard.bool(forKey: hasShownLaunchPaywallKey)
    }

    /// 首次冷启动跳过冷启动 Paywall，让用户先看到分贝读数。
    static var shouldDeferLaunchPaywallOnColdStart: Bool {
        coldLaunchCount <= 1 && !hasShownLaunchPaywall
    }

    @discardableResult
    static func recordColdLaunch() -> Int {
        let next = coldLaunchCount + 1
        UserDefaults.standard.set(next, forKey: coldLaunchCountKey)
        return next
    }

    static func markLaunchPaywallShown() {
        UserDefaults.standard.set(true, forKey: hasShownLaunchPaywallKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: coldLaunchCountKey)
        UserDefaults.standard.removeObject(forKey: hasShownLaunchPaywallKey)
    }
    #endif
}
