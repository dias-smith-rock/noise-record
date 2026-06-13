import FirebaseCore
import UIKit

/// Ensures Firebase is configured before SwiftUI `App` body runs.
final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppTelemetry.configure()
        return true
    }
}
