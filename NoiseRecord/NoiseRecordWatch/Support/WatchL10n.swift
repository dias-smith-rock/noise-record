import Foundation

enum WatchL10n {
    static var appTitle: String { string("dashboard.title") }
    static var start: String { string("dashboard.button.start") }
    static var stop: String { string("dashboard.button.stop") }
    static var max: String { string("dashboard.stat.max") }
    static var min: String { string("dashboard.stat.min") }
    static var avg: String { string("dashboard.stat.avg") }
    static var leq: String { string("dashboard.stat.leq") }
    static var standardMode: String { string("mode.standard.segmentLabel") }
    static var highSensitivityMode: String { string("mode.highSensitivity.segmentLabel") }
    static var modeLabel: String { string("watch.mode.label") }
    static var micPermissionTitle: String { string("permission.microphone.denied.title") }
    static var micPermissionMessage: String { string("permission.microphone.denied.message") }
    static var micPermissionDenied: String { string("error.audio.permissionDenied") }
    static var audioActivationFailed: String { string("error.audio.activationFailed") }
    static var disclaimer: String { string("settings.disclaimer.body") }
    static var batteryNotice: String { string("watch.monitoring.batteryNotice") }
    static var runtimeExpired: String { string("watch.runtime.expired") }
    static var runtimeResigned: String { string("watch.runtime.resigned") }
    static var runtimeSuppressed: String { string("watch.runtime.suppressed") }
    static var runtimeEnded: String { string("watch.runtime.ended") }
    static var runtimeWillExpire: String { string("watch.runtime.willExpire") }
    static var runtimeError: String { string("watch.runtime.error") }

    static var riskQuiet: String { string("noiseRisk.quiet") }
    static var riskModerate: String { string("noiseRisk.moderate") }
    static var riskLoud: String { string("noiseRisk.loud") }
    static var riskDangerous: String { string("noiseRisk.dangerous") }

    static func engineStartFailed(_ detail: String) -> String {
        String(format: string("error.engine.startFailed"), detail)
    }

    private static func string(_ key: String) -> String {
        String(
            localized: String.LocalizationValue(key),
            bundle: .main,
            locale: Locale(identifier: "en")
        )
    }
}
