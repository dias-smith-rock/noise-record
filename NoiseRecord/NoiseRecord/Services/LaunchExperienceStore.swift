import Foundation

/// 冷启动体验状态：首次启动先交付价值，再展示 Paywall。
nonisolated enum LaunchExperienceStore {
    private static let coldLaunchCountKey = "launch.coldLaunchCount"
    private static let hasShownLaunchPaywallKey = "launch.hasShownLaunchPaywall"
    private static let firstInstallDateKey = "launch.firstInstallDate"

    static var coldLaunchCount: Int {
        max(0, UserDefaults.standard.integer(forKey: coldLaunchCountKey))
    }

    static var hasShownLaunchPaywall: Bool {
        UserDefaults.standard.bool(forKey: hasShownLaunchPaywallKey)
    }

    static var firstInstallDate: Date? {
        guard UserDefaults.standard.object(forKey: firstInstallDateKey) != nil else { return nil }
        return Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: firstInstallDateKey))
    }

    static var isFirstInstallDay: Bool {
        guard let firstInstallDate else { return true }
        return Calendar.current.isDateInToday(firstInstallDate)
    }

    /// 新用户安装当天不请求、不展示广告，也不触发 UMP / ATT 同意流程。
    static var allowsAdsOnFirstInstallDay: Bool {
        !isFirstInstallDay
    }

    /// 首次冷启动跳过冷启动 Paywall，让用户先看到分贝读数。
    static var shouldDeferLaunchPaywallOnColdStart: Bool {
        coldLaunchCount <= 1 && !hasShownLaunchPaywall
    }

    @discardableResult
    static func recordColdLaunch() -> Int {
        recordFirstInstallIfNeeded()
        let next = coldLaunchCount + 1
        UserDefaults.standard.set(next, forKey: coldLaunchCountKey)
        return next
    }

    static func recordFirstInstallIfNeeded() {
        guard firstInstallDate == nil else { return }
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: firstInstallDateKey)
        AppTelemetry.setInstallCohortProperties(installDate: now)
    }

    static func markLaunchPaywallShown() {
        UserDefaults.standard.set(true, forKey: hasShownLaunchPaywallKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: coldLaunchCountKey)
        UserDefaults.standard.removeObject(forKey: hasShownLaunchPaywallKey)
        UserDefaults.standard.removeObject(forKey: firstInstallDateKey)
    }
    #endif
}
