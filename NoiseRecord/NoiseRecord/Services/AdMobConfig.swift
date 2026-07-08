import Foundation

nonisolated enum AdMobConfig {
    static let appID = "ca-app-pub-2283581832994740~9865795031"

    #if DEBUG
    static let isDebugBuild = true
    /// Google test ad units for Debug verification.
    static let coldStartAppOpen = "ca-app-pub-3940256099942544/5575463023"
    static let hotStartInterstitial = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let isDebugBuild = false
    static let coldStartAppOpen = "ca-app-pub-2283581832994740/5926550020"
    static let hotStartInterstitial = "ca-app-pub-2283581832994740/7790296034"
    #endif

    /// 与 Release 一致：已买断去广告的用户不展示广告；Debug 使用 Google 测试广告位。
    static var adsEnabled: Bool {
        !SubscriptionManager.adsRemovedSnapshot
    }

    static let appOpenAdTimeout: TimeInterval = 4 * 60 * 60
    static let presentationRetryDelayMs = 300
    static let maxPresentationRetries = 3
    /// Delay after scene active / didBecomeActive before UMP (and ATT) presentation.
    static let consentPresentationDelaySeconds: TimeInterval = 1.0
}
