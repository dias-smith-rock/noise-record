import Foundation

nonisolated enum AppLocalization {
    static let languageKey = "app.preferredLanguage"

    static var resolvedLocale: Locale {
        let code = UserDefaults.standard.string(forKey: languageKey) ?? AppLanguage.system.rawValue
        if code == AppLanguage.system.rawValue {
            return .current
        }
        return Locale(identifier: code)
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, locale: resolvedLocale)
    }
}
