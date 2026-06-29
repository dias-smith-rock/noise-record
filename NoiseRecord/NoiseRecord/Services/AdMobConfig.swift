import Foundation

nonisolated enum AdMobConfig {
    static let appID = "ca-app-pub-2283581832994740~9865795031"

    #if DEBUG
    static let isDebugBuild = true
    /// Debug 构建默认不展示广告；Release 下仍受 IAP 免广告权益控制。
    static let adsEnabled = false
    /// Google test ad units (unused while `adsEnabled` is false in debug).
    static let coldStartAppOpen = "ca-app-pub-3940256099942544/5575463023"
    static let hotStartInterstitial = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let isDebugBuild = false
    static var adsEnabled: Bool {
        !SubscriptionManager.adsRemovedSnapshot
    }
    static let coldStartAppOpen = "ca-app-pub-2283581832994740/5926550020"
    static let hotStartInterstitial = "ca-app-pub-2283581832994740/7790296034"
    #endif

    static let appOpenAdTimeout: TimeInterval = 4 * 60 * 60
    static let presentationRetryDelayMs = 300
    static let maxPresentationRetries = 3
    /// Delay after scene active / didBecomeActive before UMP (and ATT) presentation.
    static let consentPresentationDelaySeconds: TimeInterval = 1.0
}
