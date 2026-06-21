import Foundation

nonisolated enum AppLocalization {
    static let languageKey = "app.preferredLanguage"

    private static let lock = NSLock()
    private static var activeLanguage: AppLanguage = loadPersistedLanguage()

    static func setActiveLanguage(_ language: AppLanguage) {
        lock.lock()
        activeLanguage = language
        lock.unlock()
    }

    static func currentLanguage() -> AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return activeLanguage
    }

    static func resolvedLocale(for language: AppLanguage? = nil) -> Locale {
        let code = resourceCode(for: language ?? currentLanguage())
        return Locale(identifier: code)
    }

    static var resolvedLocale: Locale {
        resolvedLocale(for: nil)
    }

    static func string(_ key: String.LocalizationValue, language: AppLanguage? = nil) -> String {
        String(localized: key, bundle: bundle(for: language))
    }

    static func bundle(for language: AppLanguage? = nil) -> Bundle {
        let code = resourceCode(for: language ?? currentLanguage())
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    private static func loadPersistedLanguage() -> AppLanguage {
        let raw = UserDefaults.standard.string(forKey: languageKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    private static let availableResourceCodes = [
        "ar", "bg", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr", "he", "hi", "hr", "hu",
        "id", "it", "ja", "ko", "ms", "nb", "nl", "pl", "pt", "ro", "ru", "sk", "sv", "th", "tr",
        "uk", "vi", "zh-Hans", "zh-Hant",
    ]

    private static func resourceCode(for language: AppLanguage) -> String {
        switch language {
        case .system:
            for candidate in systemLocaleCandidates() {
                if let code = matchAvailableResourceCode(candidate) {
                    return code
                }
            }
            return "en"
        default:
            return language.rawValue
        }
    }

    private static func systemLocaleCandidates() -> [String] {
        var candidates: [String] = []
        if let preferred = Locale.preferredLanguages.first {
            candidates.append(Locale(identifier: preferred).identifier.replacingOccurrences(of: "_", with: "-"))
        }
        candidates.append(Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
        return candidates
    }

    private static func matchAvailableResourceCode(_ identifier: String) -> String? {
        if availableResourceCodes.contains(identifier) {
            return identifier
        }
        for code in availableResourceCodes where identifier.hasPrefix(code) {
            return code
        }
        let base = Locale(identifier: identifier).language.languageCode?.identifier ?? ""
        if availableResourceCodes.contains(base) {
            return base
        }
        return nil
    }
}
