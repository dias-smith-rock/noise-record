import FirebaseCore
import GoogleMobileAds
import UIKit

/// App bootstrap: Firebase, AdMob, and cold/hot-start ad lifecycle.
final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    private var isColdStart = true
    private var wasInBackground = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppTelemetry.configure()
        MobileAds.shared.start { _ in
            Task { @MainActor in
                AppOpenAdManager.shared.loadAd()
                HotStartAdManager.shared.loadAd()
            }
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            if isColdStart {
                AppOpenAdManager.shared.showAdIfAvailable()
                isColdStart = false
            } else if wasInBackground {
                HotStartAdManager.shared.showAdIfAvailable()
                wasInBackground = false
            }
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Task { @MainActor in
            HotStartAdManager.shared.loadAd()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        wasInBackground = true
        Task { @MainActor in
            HotStartAdManager.shared.loadAd()
        }
    }
}
