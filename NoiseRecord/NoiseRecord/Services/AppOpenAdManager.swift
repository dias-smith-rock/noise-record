import GoogleMobileAds
import UIKit

@MainActor
final class AppOpenAdManager: NSObject {
    static let shared = AppOpenAdManager()

    private var appOpenAd: AppOpenAd?
    private var loadTime: Date?
    private var isShowingAd = false
    private var isLoadingAd = false

    private override init() {
        super.init()
    }

    func loadAd() {
        guard !isLoadingAd, !isShowingAd else { return }
        isLoadingAd = true

        AppOpenAd.load(with: AdMobConfig.coldStartAppOpen, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingAd = false

                if let error {
                    AppTelemetry.logAdColdFail(error.localizedDescription)
                    return
                }

                self.appOpenAd = ad
                self.loadTime = Date()
                ad?.fullScreenContentDelegate = self
                AppTelemetry.logAdColdLoad()
            }
        }
    }

    func showAdIfAvailable(retryCount: Int = 0) {
        guard !isShowingAd else { return }

        if appOpenAd == nil || isAdExpired {
            loadAd()
            scheduleRetry(retryCount: retryCount)
            return
        }

        guard let root = UIApplication.shared.topViewController else {
            scheduleRetry(retryCount: retryCount)
            return
        }

        guard let appOpenAd else { return }

        isShowingAd = true
        appOpenAd.present(from: root)
        AppTelemetry.logAdColdShow()
    }

    private var isAdExpired: Bool {
        guard let loadTime else { return true }
        return Date().timeIntervalSince(loadTime) > AdMobConfig.appOpenAdTimeout
    }

    private func scheduleRetry(retryCount: Int) {
        guard retryCount < AdMobConfig.maxPresentationRetries else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(AdMobConfig.presentationRetryDelayMs))
            showAdIfAvailable(retryCount: retryCount + 1)
        }
    }

    private func clearAd() {
        isShowingAd = false
        appOpenAd = nil
        loadTime = nil
    }
}

extension AppOpenAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        clearAd()
        loadAd()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        AppTelemetry.logAdColdFail(error.localizedDescription)
        clearAd()
        loadAd()
    }
}
