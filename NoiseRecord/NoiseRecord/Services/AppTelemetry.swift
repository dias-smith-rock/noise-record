import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// Firebase Analytics + Crashlytics bootstrap and logging helpers.
nonisolated enum AppTelemetry {
    static let maxAnalyticsParameterCount = 5
    static let maxAnalyticsParameterLength = 100

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

    static func logProductEvent(
        _ action: String,
        parameters: [String: String] = [:]
    ) {
        let eventName = "product_\(action)"
        let metadataSummary = parameters.isEmpty
            ? ""
            : " " + parameters.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        log("product.\(action)\(metadataSummary)")
        logEvent(eventName, parameters: sanitizedAnalyticsParameters(parameters))
    }

    static func logCommercialEvent(
        domain: String,
        outcome: String,
        metadata: [String: String] = [:]
    ) {
        let eventName = "commercial_\(domain)_\(outcome)"
        let metadataSummary = metadata.isEmpty
            ? ""
            : " " + metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        log("commercial.\(domain).\(outcome)\(metadataSummary)")
        logEvent(eventName, parameters: sanitizedAnalyticsParameters(metadata))
    }

    static func sanitizedAnalyticsParameters(_ parameters: [String: String]) -> [String: Any]? {
        guard !parameters.isEmpty else { return nil }
        var sanitized: [String: Any] = [:]
        for (index, entry) in parameters.sorted(by: { $0.key < $1.key }).prefix(maxAnalyticsParameterCount).enumerated() {
            sanitized[entry.key] = truncatedAnalyticsValue(entry.value)
            if index >= maxAnalyticsParameterCount - 1 { break }
        }
        return sanitized
    }

    static func truncatedAnalyticsValue(_ value: String) -> String {
        String(value.prefix(maxAnalyticsParameterLength))
    }

    static func commercialAdOutcome(for step: String) -> String? {
        switch step {
        case "show_presenting":
            return "show"
        case "dismissed":
            return "dismiss"
        case "load_failed", "load_failed_empty_ad", "show_failed":
            return "fail"
        default:
            return nil
        }
    }

    static func commercialIAPOutcome(for step: String) -> String? {
        switch step {
        case "purchase_verified":
            return "purchase_success"
        case "restore_succeeded":
            return "restore_success"
        case "product_load_not_found":
            return "product_missing"
        default:
            return nil
        }
    }

    static func recordError(_ error: Error, context: String) {
        log("\(context): \(error.localizedDescription)")
        Crashlytics.crashlytics().record(error: error)
        logEvent(
            "app_error",
            parameters: [
                "context": truncatedAnalyticsValue(context),
                "message": truncatedAnalyticsValue(error.localizedDescription),
            ]
        )
    }

    static func recordMessage(_ message: String, context: String) {
        log("\(context): \(message)")
        logEvent(
            "app_error",
            parameters: [
                "context": truncatedAnalyticsValue(context),
                "message": truncatedAnalyticsValue(message),
            ]
        )
    }

    static func setMonitoringActive(_ isActive: Bool) {
        Crashlytics.crashlytics().setCustomValue(isActive, forKey: "monitoring_active")
        logEvent("monitoring_state", parameters: ["active": isActive])
    }

    static func logMonitorStart() {
        log("monitor_start")
        logEvent("monitor_start")
    }

    static func logVideoRecordingStart() {
        log("video_recording_start")
        logEvent("video_recording_start")
    }

    static func logBackgroundRecordingStart(peakDB: Float) {
        log("background_recording_start peak_db=\(Int(peakDB))")
        logEvent(
            "background_recording_start",
            parameters: ["peak_db": Int(peakDB)]
        )
    }

    static func logAdColdLoad() {
        log("ad.cold.load")
    }

    static func logAdColdShow() {
        logCommercialEvent(domain: "ad", outcome: "show", metadata: ["channel": "cold"])
    }

    static func logAdColdFail(_ message: String) {
        logCommercialEvent(
            domain: "ad",
            outcome: "fail",
            metadata: [
                "channel": "cold",
                "message": message,
            ]
        )
    }

    static func logAdHotLoad() {
        log("ad.hot.load")
    }

    static func logAdHotShow() {
        logCommercialEvent(domain: "ad", outcome: "show", metadata: ["channel": "hot"])
    }

    static func logAdHotFail(_ message: String) {
        logCommercialEvent(
            domain: "ad",
            outcome: "fail",
            metadata: [
                "channel": "hot",
                "message": message,
            ]
        )
    }

    /// Structured IAP lifecycle logs for StoreKit troubleshooting.
    static func logIAPLifecycle(
        step: String,
        metadata: [String: String] = [:]
    ) {
        let metadataSummary = metadata.isEmpty
            ? ""
            : " " + metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        log("iap.\(step)\(metadataSummary)")

        if let outcome = commercialIAPOutcome(for: step) {
            var commercialMetadata = metadata
            commercialMetadata["step"] = step
            logCommercialEvent(domain: "iap", outcome: outcome, metadata: commercialMetadata)
        }
    }

    /// Structured ad lifecycle logs for cold/hot start troubleshooting.
    static func logAdLifecycle(
        channel: String,
        step: String,
        metadata: [String: String] = [:]
    ) {
        let metadataSummary = metadata.isEmpty
            ? ""
            : " " + metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        log("ad.\(channel).\(step)\(metadataSummary)")

        if let outcome = commercialAdOutcome(for: step) {
            var commercialMetadata = metadata
            commercialMetadata["channel"] = channel
            commercialMetadata["step"] = step
            logCommercialEvent(domain: "ad", outcome: outcome, metadata: commercialMetadata)
        }
    }

    /// 7 段数码管字体加载链路诊断。
    static func logUIFontDiagnostics(
        step: String,
        metadata: [String: String] = [:]
    ) {
        let metadataSummary = metadata.isEmpty
            ? ""
            : " " + metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        log("ui_font.\(step)\(metadataSummary)")
    }

    private static func configureCrashlyticsContext() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        Crashlytics.crashlytics().setCustomValue("\(version) (\(build))", forKey: "app_version")
    }
}
