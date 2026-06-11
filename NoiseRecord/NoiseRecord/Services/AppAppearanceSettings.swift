import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case en
    case ar
    case es
    case fr
    case hi
    case pt
    case ru
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            AppLocalization.string("settings.language.system")
        case .en:
            "English"
        case .ar:
            "العربية"
        case .es:
            "Español"
        case .fr:
            "Français"
        case .hi:
            "हिन्दी"
        case .pt:
            "Português"
        case .ru:
            "Русский"
        case .zhHans:
            "简体中文"
        case .zhHant:
            "繁體中文"
        }
    }
}

enum AppColorSchemePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            AppLocalization.string("settings.theme.system")
        case .light:
            AppLocalization.string("settings.theme.light")
        case .dark:
            AppLocalization.string("settings.theme.dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

@Observable
@MainActor
final class AppAppearanceSettings {
    static let shared = AppAppearanceSettings()

    private static let colorSchemeKey = "app.colorSchemePreference"

    var preferredLanguage: AppLanguage {
        didSet {
            guard oldValue != preferredLanguage else { return }
            Self.persistLanguage(preferredLanguage)
            languageRefreshID = UUID()
        }
    }

    var colorSchemePreference: AppColorSchemePreference {
        didSet {
            UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: Self.colorSchemeKey)
        }
    }

    private(set) var languageRefreshID = UUID()

    private init() {
        let languageRaw = UserDefaults.standard.string(forKey: AppLocalization.languageKey) ?? AppLanguage.system.rawValue
        preferredLanguage = AppLanguage(rawValue: languageRaw) ?? .system

        let schemeRaw = UserDefaults.standard.string(forKey: Self.colorSchemeKey) ?? AppColorSchemePreference.system.rawValue
        colorSchemePreference = AppColorSchemePreference(rawValue: schemeRaw) ?? .system
    }

    private static func persistLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: AppLocalization.languageKey)
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}
