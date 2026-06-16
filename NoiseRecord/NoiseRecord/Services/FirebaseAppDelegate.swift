import GoogleMobileAds
import UIKit

/// App bootstrap: AdMob lifecycle (Firebase configured in `NoiseRecordApp.init`).
final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LaunchPerformance.mark(.launchDelegateEntry)
        AppTelemetry.logAdLifecycle(
            channel: "bootstrap",
            step: "did_finish_launching",
            metadata: [
                "debug_build": String(describing: AdMobConfig.isDebugBuild),
                "cold_unit": AdMobConfig.coldStartAppOpen,
                "hot_unit": AdMobConfig.hotStartInterstitial,
            ]
        )

        Task { @MainActor in
            await LaunchPerformance.whenFirstInteractive()
            guard await AdConsentManager.gatherConsentIfNeeded() else { return }
            startAdMob()
        }
        return true
    }

    @MainActor
    private func startAdMob() {
        guard AdMobConfig.adsEnabled else {
            AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "admob_skipped_debug")
            return
        }

        guard AdConsentManager.canRequestAds else {
            AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "admob_skipped_no_consent")
            return
        }

        LaunchPerformance.mark(.launchAdMobStartRequested)
        AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "admob_start_requested")

        MobileAds.shared.start { status in
            Task { @MainActor in
                LaunchPerformance.mark(.launchAdMobStartCompleted)
                AppTelemetry.logAdLifecycle(
                    channel: "bootstrap",
                    step: "admob_start_completed",
                    metadata: [
                        "adapter_count": String(status.adapterStatusesByClassName.count),
                    ]
                )
                for (adapter, adapterStatus) in status.adapterStatusesByClassName {
                    AppTelemetry.logAdLifecycle(
                        channel: "bootstrap",
                        step: "admob_adapter_status",
                        metadata: [
                            "adapter": adapter,
                            "state": String(describing: adapterStatus.state),
                            "description": adapterStatus.description,
                        ]
                    )
                }
                AppOpenAdManager.shared.loadAd()
                HotStartAdManager.shared.loadAd()
            }
        }
    }
}
