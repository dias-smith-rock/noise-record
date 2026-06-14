import FirebaseCore
import GoogleMobileAds
import UIKit

/// App bootstrap: Firebase, AdMob, and cold/hot-start ad lifecycle.
final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppTelemetry.configure()
        AppTelemetry.logAdLifecycle(
            channel: "bootstrap",
            step: "did_finish_launching",
            metadata: [
                "debug_build": String(describing: AdMobConfig.isDebugBuild),
                "cold_unit": AdMobConfig.coldStartAppOpen,
                "hot_unit": AdMobConfig.hotStartInterstitial,
            ]
        )

        AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "admob_start_requested")
        MobileAds.shared.start { status in
            Task { @MainActor in
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
        return true
    }
}
