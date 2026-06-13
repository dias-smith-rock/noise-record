import Foundation

nonisolated enum AdMobConfig {
    static let appID = "ca-app-pub-2283581832994740~9865795031"

    #if DEBUG
    /// Google test ad units — avoid invalid traffic during development.
    static let coldStartAppOpen = "ca-app-pub-3940256099942544/5575463023"
    static let hotStartInterstitial = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let coldStartAppOpen = "ca-app-pub-2283581832994740/5926550020"
    static let hotStartInterstitial = "ca-app-pub-2283581832994740/7790296034"
    #endif

    static let appOpenAdTimeout: TimeInterval = 4 * 60 * 60
    static let presentationRetryDelayMs = 300
    static let maxPresentationRetries = 3
}
