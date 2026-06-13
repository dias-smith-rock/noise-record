import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// Firebase Analytics + Crashlytics bootstrap and logging helpers.
nonisolated enum AppTelemetry {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        configureCrashlyticsContext()
        log("firebase_configured")
        logEvent("app_launch")
    }

    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
        #if DEBUG
        print("[AppTelemetry] \(message)")
        #endif
    }

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
        #if DEBUG
        if let parameters {
            print("[AppTelemetry] event \(name) \(parameters)")
        } else {
            print("[AppTelemetry] event \(name)")
        }
        #endif
    }

    static func recordError(_ error: Error, context: String) {
        log("\(context): \(error.localizedDescription)")
        Crashlytics.crashlytics().record(error: error)
        logEvent(
            "app_error",
            parameters: [
                "context": context,
                "message": error.localizedDescription,
            ]
        )
    }

    static func recordMessage(_ message: String, context: String) {
        log("\(context): \(message)")
        logEvent(
            "app_error",
            parameters: [
                "context": context,
                "message": message,
            ]
        )
    }

    static func setMonitoringActive(_ isActive: Bool) {
        Crashlytics.crashlytics().setCustomValue(isActive, forKey: "monitoring_active")
        logEvent("monitoring_state", parameters: ["active": isActive])
    }

    static func logAdColdLoad() {
        logEvent("ad_cold_load")
    }

    static func logAdColdShow() {
        logEvent("ad_cold_show")
    }

    static func logAdColdFail(_ message: String) {
        logEvent("ad_cold_fail", parameters: ["message": message])
    }

    static func logAdHotLoad() {
        logEvent("ad_hot_load")
    }

    static func logAdHotShow() {
        logEvent("ad_hot_show")
    }

    static func logAdHotFail(_ message: String) {
        logEvent("ad_hot_fail", parameters: ["message": message])
    }

    private static func configureCrashlyticsContext() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        Crashlytics.crashlytics().setCustomValue("\(version) (\(build))", forKey: "app_version")
    }
}
