import UIKit

/// App bootstrap: AdMob lifecycle (Firebase configured in `NoiseRecordApp.init`).
final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    private var didBecomeActiveObserver: NSObjectProtocol?

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

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
            }
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
        }
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }
}
