import GoogleMobileAds
import UIKit

@MainActor
final class HotStartAdManager: NSObject {
    static let shared = HotStartAdManager()

    private var interstitial: InterstitialAd?
    private var isShowingAd = false
    private var isLoadingAd = false

    private override init() {
        super.init()
    }

    func loadAd() {
        guard !isLoadingAd, !isShowingAd else { return }
        isLoadingAd = true

        InterstitialAd.load(with: AdMobConfig.hotStartInterstitial, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingAd = false

                if let error {
                    AppTelemetry.logAdHotFail(error.localizedDescription)
                    return
                }

                self.interstitial = ad
                ad?.fullScreenContentDelegate = self
                AppTelemetry.logAdHotLoad()
            }
        }
    }

    func showAdIfAvailable(retryCount: Int = 0) {
        guard !isShowingAd else { return }

        guard let interstitial else {
            loadAd()
            scheduleRetry(retryCount: retryCount)
            return
        }

        guard let root = UIApplication.shared.topViewController else {
            scheduleRetry(retryCount: retryCount)
            return
        }

        isShowingAd = true
        interstitial.present(from: root)
        AppTelemetry.logAdHotShow()
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
        interstitial = nil
    }
}

extension HotStartAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        clearAd()
        loadAd()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        AppTelemetry.logAdHotFail(error.localizedDescription)
        clearAd()
        loadAd()
    }
}
