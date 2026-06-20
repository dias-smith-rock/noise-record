import SwiftUI
import UIKit

enum AccentColorChoice: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case preset
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            AppLocalization.string("settings.accentColor.automatic")
        case .preset:
            AppLocalization.string("settings.accentColor.preset")
        case .custom:
            AppLocalization.string("settings.accentColor.custom")
        }
    }
}

enum AppAccentPreset: String, CaseIterable, Identifiable, Sendable {
    case teal
    case orange
    case blue
    case purple
    case green
    case coral
    case indigo

    var id: String { rawValue }

    var storedRGB: StoredRGB {
        switch self {
        case .teal:
            StoredRGB(red: 0.16, green: 0.52, blue: 0.68)
        case .orange:
            StoredRGB(red: 0.90, green: 0.46, blue: 0.14)
        case .blue:
            StoredRGB(red: 0.20, green: 0.48, blue: 0.92)
        case .purple:
            StoredRGB(red: 0.55, green: 0.36, blue: 0.86)
        case .green:
            StoredRGB(red: 0.18, green: 0.72, blue: 0.44)
        case .coral:
            StoredRGB(red: 0.94, green: 0.36, blue: 0.36)
        case .indigo:
            StoredRGB(red: 0.32, green: 0.34, blue: 0.78)
        }
    }

    var color: Color { storedRGB.color }

    var displayName: String {
        switch self {
        case .teal:
            AppLocalization.string("settings.accent.preset.teal")
        case .orange:
            AppLocalization.string("settings.accent.preset.orange")
        case .blue:
            AppLocalization.string("settings.accent.preset.blue")
        case .purple:
            AppLocalization.string("settings.accent.preset.purple")
        case .green:
            AppLocalization.string("settings.accent.preset.green")
        case .coral:
            AppLocalization.string("settings.accent.preset.coral")
        case .indigo:
            AppLocalization.string("settings.accent.preset.indigo")
        }
    }
}

struct StoredRGB: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(color: Color) {
        let components = UIColor(color).cgColor.components ?? [0, 0, 0, 1]
        if components.count >= 3 {
            red = Double(components[0])
            green = Double(components[1])
            blue = Double(components[2])
        } else {
            red = Double(components[0])
            green = Double(components[0])
            blue = Double(components[0])
        }
    }

    func isApproximatelyEqual(to other: StoredRGB, accuracy: Double = 0.02) -> Bool {
        abs(red - other.red) <= accuracy
            && abs(green - other.green) <= accuracy
            && abs(blue - other.blue) <= accuracy
    }
}

struct ModeAccentPreference: Equatable, Sendable {
    var choice: AccentColorChoice
    var preset: AppAccentPreset
    var customRGB: StoredRGB

    static let defaultStandard = ModeAccentPreference(
        choice: .automatic,
        preset: .teal,
        customRGB: AppAccentPreset.teal.storedRGB
    )

    static let defaultHighSensitivity = ModeAccentPreference(
        choice: .automatic,
        preset: .orange,
        customRGB: AppAccentPreset.orange.storedRGB
    )

    var summaryLabel: String {
        switch choice {
        case .automatic:
            AccentColorChoice.automatic.title
        case .preset:
            preset.displayName
        case .custom:
            AccentColorChoice.custom.title
        }
    }

    func resolvedRGB(builtin: StoredRGB) -> StoredRGB {
        switch choice {
        case .automatic:
            builtin
        case .preset:
            preset.storedRGB
        case .custom:
            customRGB
        }
    }

    func resolvedColor(builtin: Color) -> Color {
        resolvedRGB(builtin: StoredRGB(color: builtin)).color
    }
}

enum ModeAccentPersistence {
    private static let standardChoiceKey = "app.standardAccent.choice"
    private static let standardPresetKey = "app.standardAccent.preset"
    private static let standardCustomRKey = "app.standardAccent.customR"
    private static let standardCustomGKey = "app.standardAccent.customG"
    private static let standardCustomBKey = "app.standardAccent.customB"

    private static let highSensitivityChoiceKey = "app.highSensitivityAccent.choice"
    private static let highSensitivityPresetKey = "app.highSensitivityAccent.preset"
    private static let highSensitivityCustomRKey = "app.highSensitivityAccent.customR"
    private static let highSensitivityCustomGKey = "app.highSensitivityAccent.customG"
    private static let highSensitivityCustomBKey = "app.highSensitivityAccent.customB"

    static func load(for mode: AcousticMeasurementMode, defaults: UserDefaults = .standard) -> ModeAccentPreference {
        let fallback = mode == .standard ? ModeAccentPreference.defaultStandard : ModeAccentPreference.defaultHighSensitivity
        let choiceKey = mode == .standard ? standardChoiceKey : highSensitivityChoiceKey
        let presetKey = mode == .standard ? standardPresetKey : highSensitivityPresetKey
        let customRKey = mode == .standard ? standardCustomRKey : highSensitivityCustomRKey
        let customGKey = mode == .standard ? standardCustomGKey : highSensitivityCustomGKey
        let customBKey = mode == .standard ? standardCustomBKey : highSensitivityCustomBKey

        let choiceRaw = defaults.string(forKey: choiceKey) ?? AccentColorChoice.automatic.rawValue
        let choice = AccentColorChoice(rawValue: choiceRaw) ?? .automatic

        let presetRaw = defaults.string(forKey: presetKey) ?? fallback.preset.rawValue
        let preset = AppAccentPreset(rawValue: presetRaw) ?? fallback.preset

        let customRGB: StoredRGB
        if defaults.object(forKey: customRKey) != nil {
            customRGB = StoredRGB(
                red: defaults.double(forKey: customRKey),
                green: defaults.double(forKey: customGKey),
                blue: defaults.double(forKey: customBKey)
            )
        } else {
            customRGB = fallback.customRGB
        }

        return ModeAccentPreference(choice: choice, preset: preset, customRGB: customRGB)
    }

    static func save(_ preference: ModeAccentPreference, for mode: AcousticMeasurementMode, defaults: UserDefaults = .standard) {
        let choiceKey = mode == .standard ? standardChoiceKey : highSensitivityChoiceKey
        let presetKey = mode == .standard ? standardPresetKey : highSensitivityPresetKey
        let customRKey = mode == .standard ? standardCustomRKey : highSensitivityCustomRKey
        let customGKey = mode == .standard ? standardCustomGKey : highSensitivityCustomGKey
        let customBKey = mode == .standard ? standardCustomBKey : highSensitivityCustomBKey

        defaults.set(preference.choice.rawValue, forKey: choiceKey)
        defaults.set(preference.preset.rawValue, forKey: presetKey)
        defaults.set(preference.customRGB.red, forKey: customRKey)
        defaults.set(preference.customRGB.green, forKey: customGKey)
        defaults.set(preference.customRGB.blue, forKey: customBKey)
    }
}
