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

enum TemperatureUnitPreference: String, CaseIterable, Identifiable, Sendable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .celsius:
            AppLocalization.string("settings.temperature.celsius")
        case .fahrenheit:
            AppLocalization.string("settings.temperature.fahrenheit")
        }
    }

    var usesFahrenheit: Bool {
        self == .fahrenheit
    }
}

@Observable
@MainActor
final class AppAppearanceSettings {
    static let shared = AppAppearanceSettings()

    private static let colorSchemeKey = "app.colorSchemePreference"
    private static let temperatureUnitKey = "app.temperatureUnitPreference"

    var preferredLanguage: AppLanguage {
        didSet {
            guard oldValue != preferredLanguage else { return }
            Self.persistLanguage(preferredLanguage)
            languageRefreshID = UUID()
            DispatchQueue.main.async {
                TabBarAppearanceUpdater.applyTabTitles()
            }
        }
    }

    var colorSchemePreference: AppColorSchemePreference {
        didSet {
            UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: Self.colorSchemeKey)
        }
    }

    var temperatureUnitPreference: TemperatureUnitPreference {
        didSet {
            UserDefaults.standard.set(temperatureUnitPreference.rawValue, forKey: Self.temperatureUnitKey)
        }
    }

    private(set) var languageRefreshID = UUID()

    private init() {
        let schemeRaw = UserDefaults.standard.string(forKey: Self.colorSchemeKey) ?? AppColorSchemePreference.system.rawValue
        colorSchemePreference = AppColorSchemePreference(rawValue: schemeRaw) ?? .system

        if let temperatureRaw = UserDefaults.standard.string(forKey: Self.temperatureUnitKey),
           let savedUnit = TemperatureUnitPreference(rawValue: temperatureRaw) {
            temperatureUnitPreference = savedUnit
        } else {
            temperatureUnitPreference = Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
        }

        let languageRaw = UserDefaults.standard.string(forKey: AppLocalization.languageKey) ?? AppLanguage.system.rawValue
        preferredLanguage = AppLanguage(rawValue: languageRaw) ?? .system
        AppLocalization.setActiveLanguage(preferredLanguage)
    }

    private static func persistLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: AppLocalization.languageKey)
        AppLocalization.setActiveLanguage(language)
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}
