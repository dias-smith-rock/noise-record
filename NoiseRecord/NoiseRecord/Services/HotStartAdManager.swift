import GoogleMobileAds
import UIKit

@MainActor
final class HotStartAdManager: NSObject {
    static let shared = HotStartAdManager()

    private var interstitial: InterstitialAd?
    private var isShowingAd = false
    private var isLoadingAd = false
    private var pendingShowAfterLoad = false

    private override init() {
        super.init()
    }

    func loadAd() {
        guard AdMobConfig.adsEnabled, AdConsentManager.canRequestAds else { return }

        if isLoadingAd {
            AppTelemetry.logAdLifecycle(channel: "hot", step: "load_skipped_already_loading")
            return
        }
        if isShowingAd {
            AppTelemetry.logAdLifecycle(channel: "hot", step: "load_skipped_already_showing")
            return
        }

        isLoadingAd = true
        AppTelemetry.logAdLifecycle(
            channel: "hot",
            step: "load_started",
            metadata: ["unit_id": AdMobConfig.hotStartInterstitial]
        )

        InterstitialAd.load(with: AdMobConfig.hotStartInterstitial, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingAd = false

                if let error {
                    AppTelemetry.logAdHotFail(error.localizedDescription)
                    AppTelemetry.logAdLifecycle(
                        channel: "hot",
                        step: "load_failed",
                        metadata: ["error": error.localizedDescription]
                    )
                    self.pendingShowAfterLoad = false
                    return
                }

                guard let ad else {
                    AppTelemetry.logAdLifecycle(channel: "hot", step: "load_failed_empty_ad")
                    self.pendingShowAfterLoad = false
                    return
                }

                self.interstitial = ad
                ad.fullScreenContentDelegate = self
                AppTelemetry.logAdHotLoad()
                AppTelemetry.logAdLifecycle(channel: "hot", step: "load_succeeded")

                if self.pendingShowAfterLoad {
                    AppTelemetry.logAdLifecycle(channel: "hot", step: "show_after_pending_load")
                    self.showAdIfAvailable()
                }
            }
        }
    }

    func showAdIfAvailable(retryCount: Int = 0) {
        guard AdMobConfig.adsEnabled, AdConsentManager.canRequestAds else { return }

        if isShowingAd {
            AppTelemetry.logAdLifecycle(channel: "hot", step: "show_skipped_already_showing")
            return
        }

        guard let interstitial else {
            pendingShowAfterLoad = true
            AppTelemetry.logAdLifecycle(
                channel: "hot",
                step: "show_waiting_for_load",
                metadata: ["retry": String(retryCount)]
            )
            loadAd()
            scheduleRetry(retryCount: retryCount)
            return
        }

        guard let root = UIApplication.shared.topViewController else {
            AppTelemetry.logAdLifecycle(
                channel: "hot",
                step: "show_no_root_view_controller",
                metadata: ["retry": String(retryCount)]
            )
            scheduleRetry(retryCount: retryCount)
            return
        }

        pendingShowAfterLoad = false
        isShowingAd = true
        AppTelemetry.logAdLifecycle(
            channel: "hot",
            step: "show_presenting",
            metadata: [
                "root": String(describing: type(of: root)),
                "retry": String(retryCount),
            ]
        )
        interstitial.present(from: root)
        AppTelemetry.logAdHotShow()
    }

    private func scheduleRetry(retryCount: Int) {
        guard retryCount < AdMobConfig.maxPresentationRetries else {
            AppTelemetry.logAdLifecycle(
                channel: "hot",
                step: "show_retry_exhausted",
                metadata: [
                    "max_retries": String(AdMobConfig.maxPresentationRetries),
                    "pending_show_after_load": String(pendingShowAfterLoad),
                    "has_ad": String(interstitial != nil),
                ]
            )
            return
        }

        AppTelemetry.logAdLifecycle(
            channel: "hot",
            step: "show_retry_scheduled",
            metadata: [
                "retry": String(retryCount + 1),
                "delay_ms": String(AdMobConfig.presentationRetryDelayMs),
            ]
        )
        Task {
            try? await Task.sleep(for: .milliseconds(AdMobConfig.presentationRetryDelayMs))
            showAdIfAvailable(retryCount: retryCount + 1)
        }
    }

    private func clearAd() {
        isShowingAd = false
        interstitial = nil
        pendingShowAfterLoad = false
    }
}

extension HotStartAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        AppTelemetry.logAdLifecycle(channel: "hot", step: "dismissed")
        clearAd()
        loadAd()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        AppTelemetry.logAdHotFail(error.localizedDescription)
        AppTelemetry.logAdLifecycle(
            channel: "hot",
            step: "present_failed",
            metadata: ["error": error.localizedDescription]
        )
        clearAd()
        loadAd()
    }
}
