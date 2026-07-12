import UIKit
import UserNotifications

/// App bootstrap: AdMob lifecycle (Firebase configured in `NoiseRecordApp.init`).
final class FirebaseAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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

        UNUserNotificationCenter.current().delegate = self

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard LaunchExperienceStore.allowsAdsOnFirstInstallDay else { return }
                AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
            }
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            guard LaunchExperienceStore.allowsAdsOnFirstInstallDay else { return }
            AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
        }
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        InterfaceOrientationLocker.supportedMask
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = SleepNotificationRouter.handle(response: response)
        completionHandler()
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }
}
