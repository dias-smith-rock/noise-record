import GoogleMobileAds
import UIKit

@MainActor
final class AppOpenAdManager: NSObject {
    static let shared = AppOpenAdManager()

    private var appOpenAd: AppOpenAd?
    private var loadTime: Date?
    private var isShowingAd = false
    private var isLoadingAd = false
    private var pendingShowAfterLoad = false

    private override init() {
        super.init()
    }

    func loadAd() {
        guard AdMobConfig.adsEnabled, AdConsentManager.canRequestAds else { return }
        guard AdSessionPolicy.shouldAttemptAdLoadOrShow() else {
            AppTelemetry.logAdLifecycle(channel: "cold", step: "load_skipped_first_install_day")
            return
        }

        if isLoadingAd {
            AppTelemetry.logAdLifecycle(channel: "cold", step: "load_skipped_already_loading")
            return
        }
        if isShowingAd {
            AppTelemetry.logAdLifecycle(channel: "cold", step: "load_skipped_already_showing")
            return
        }

        isLoadingAd = true
        AppTelemetry.logAdLifecycle(
            channel: "cold",
            step: "load_started",
            metadata: ["unit_id": AdMobConfig.coldStartAppOpen]
        )

        AppOpenAd.load(with: AdMobConfig.coldStartAppOpen, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingAd = false

                if let error {
                    AppTelemetry.logAdLifecycle(
                        channel: "cold",
                        step: "load_failed",
                        metadata: ["error": error.localizedDescription]
                    )
                    self.pendingShowAfterLoad = false
                    return
                }

                guard let ad else {
                    AppTelemetry.logAdLifecycle(channel: "cold", step: "load_failed_empty_ad")
                    self.pendingShowAfterLoad = false
                    return
                }

                self.appOpenAd = ad
                self.loadTime = Date()
                ad.fullScreenContentDelegate = self
                AppTelemetry.logAdColdLoad()
                AppTelemetry.logAdLifecycle(channel: "cold", step: "load_succeeded")

                if self.pendingShowAfterLoad {
                    AppTelemetry.logAdLifecycle(channel: "cold", step: "show_after_pending_load")
                    self.showAdIfAvailable()
                }
            }
        }
    }

    func showAdIfAvailable(retryCount: Int = 0) {
        guard AdMobConfig.adsEnabled, AdConsentManager.canRequestAds else { return }
        guard AdSessionPolicy.shouldAttemptAdLoadOrShow() else {
            pendingShowAfterLoad = false
            AppTelemetry.logAdLifecycle(channel: "cold", step: "show_skipped_first_install_day")
            return
        }

        if isShowingAd {
            AppTelemetry.logAdLifecycle(channel: "cold", step: "show_skipped_already_showing")
            return
        }

        if appOpenAd == nil {
            pendingShowAfterLoad = true
            AppTelemetry.logAdLifecycle(
                channel: "cold",
                step: "show_waiting_for_load",
                metadata: ["retry": String(retryCount)]
            )
            loadAd()
            scheduleRetry(retryCount: retryCount)
            return
        }

        if isAdExpired {
            pendingShowAfterLoad = true
            AppTelemetry.logAdLifecycle(
                channel: "cold",
                step: "show_ad_expired_reload",
                metadata: [
                    "retry": String(retryCount),
                    "loaded_age_sec": String(Int(loadedAgeSeconds)),
                ]
            )
            clearAd(keepPendingShow: true)
            loadAd()
            scheduleRetry(retryCount: retryCount)
            return
        }

        guard let root = UIApplication.shared.topViewController else {
            AppTelemetry.logAdLifecycle(
                channel: "cold",
                step: "show_no_root_view_controller",
                metadata: ["retry": String(retryCount)]
            )
            scheduleRetry(retryCount: retryCount)
            return
        }

        guard let appOpenAd else {
            AppTelemetry.logAdLifecycle(channel: "cold", step: "show_missing_ad_instance")
            scheduleRetry(retryCount: retryCount)
            return
        }

        pendingShowAfterLoad = false
        isShowingAd = true
        AdSessionPolicy.notePresentationSucceeded(channel: "cold")
        AppTelemetry.logAdLifecycle(
            channel: "cold",
            step: "show_presenting",
            metadata: [
                "root": String(describing: type(of: root)),
                "retry": String(retryCount),
            ]
        )
        appOpenAd.present(from: root)
        AppTelemetry.logAdColdShow()
    }

    private var isAdExpired: Bool {
        guard let loadTime else { return true }
        return Date().timeIntervalSince(loadTime) > AdMobConfig.appOpenAdTimeout
    }

    private var loadedAgeSeconds: Int {
        guard let loadTime else { return -1 }
        return Int(Date().timeIntervalSince(loadTime))
    }

    private func scheduleRetry(retryCount: Int) {
        guard AdSessionPolicy.canSchedulePresentationRetry(channel: "cold", retryCount: retryCount) else {
            pendingShowAfterLoad = false
            AppTelemetry.logAdLifecycle(
                channel: "cold",
                step: "show_retry_exhausted",
                metadata: [
                    "max_retries": String(AdMobConfig.maxPresentationRetries),
                    "pending_show_after_load": String(pendingShowAfterLoad),
                    "has_ad": String(appOpenAd != nil),
                ]
            )
            return
        }

        let delayMs = AdSessionPolicy.retryDelayMs(for: retryCount)
        AppTelemetry.logAdLifecycle(
            channel: "cold",
            step: "show_retry_scheduled",
            metadata: [
                "retry": String(retryCount + 1),
                "delay_ms": String(delayMs),
            ]
        )
        Task {
            try? await Task.sleep(for: .milliseconds(delayMs))
            showAdIfAvailable(retryCount: retryCount + 1)
        }
    }

    private func clearAd(keepPendingShow: Bool = false) {
        isShowingAd = false
        appOpenAd = nil
        loadTime = nil
        if !keepPendingShow {
            pendingShowAfterLoad = false
        }
    }
}

extension AppOpenAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        AppTelemetry.logAdLifecycle(channel: "cold", step: "dismissed")
        clearAd()
        loadAd()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        AppTelemetry.logAdLifecycle(
            channel: "cold",
            step: "present_failed",
            metadata: ["error": error.localizedDescription]
        )
        clearAd()
        loadAd()
    }
}
