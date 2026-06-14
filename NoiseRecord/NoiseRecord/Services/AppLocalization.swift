import Foundation

nonisolated enum AppLocalization {
    static let languageKey = "app.preferredLanguage"

    static func resolvedLocale(for language: AppLanguage? = nil) -> Locale {
        let code = language?.rawValue
            ?? UserDefaults.standard.string(forKey: languageKey)
            ?? AppLanguage.system.rawValue
        if code == AppLanguage.system.rawValue {
            return .current
        }
        return Locale(identifier: code)
    }

    static var resolvedLocale: Locale {
        resolvedLocale(for: nil)
    }

    static func string(_ key: String.LocalizationValue, language: AppLanguage? = nil) -> String {
        String(localized: key, locale: resolvedLocale(for: language))
    }
}
