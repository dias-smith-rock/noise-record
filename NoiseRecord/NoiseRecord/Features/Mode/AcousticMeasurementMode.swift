import SwiftUI

/// User-facing acoustic measurement modes mapped to underlying DSP weighting.
enum AcousticMeasurementMode: String, CaseIterable, Identifiable, Sendable {
    case standard
    case highSensitivity

    var id: String { rawValue }

    var isHighSensitivity: Bool {
        self == .highSensitivity
    }

    init(isHighSensitivity: Bool) {
        self = isHighSensitivity ? .highSensitivity : .standard
    }

    // MARK: - Product copy

    var userFacingTitle: String {
        switch self {
        case .standard: "Human Hearing Mode"
        case .highSensitivity: "Full-Band / Low-Frequency"
        }
    }

    var userFacingSubtitle: String {
        switch self {
        case .standard: "Everyday listening assessment"
        case .highSensitivity: "Physical sound pressure"
        }
    }

    /// Segmented control short label.
    var segmentLabel: String {
        switch self {
        case .standard: "Standard"
        case .highSensitivity: "High Sensitivity"
        }
    }

    var technicalBadge: String {
        switch self {
        case .standard: "dBA"
        case .highSensitivity: "dBZ / dBC"
        }
    }

    var coreDescription: String {
        switch self {
        case .standard:
            "Simulates how the human ear perceives sound, filtering frequencies we are less sensitive to."
        case .highSensitivity:
            "Disables hearing-weighted filters and system noise suppression to capture full physical sound energy."
        }
    }

    var tooltipCopy: String {
        switch self {
        case .standard:
            "[Standard] Closest to subjective hearing. Best for everyday speech, TV noise, mall crowds, or neighbor disputes. Residential noise standards (e.g. 45 dB at night) are based on this mode."
        case .highSensitivity:
            "[High Sensitivity] Captures true physical energy in the air. In a quiet room at night it can pick up AC units, fridge compressors, and pipe rumble you may not notice. Readings are usually higher—ideal for hidden noise sources, machine faults, and evidence."
        }
    }

    var tooltipHeadline: String {
        switch self {
        case .standard: "[Standard]"
        case .highSensitivity: "[High Sensitivity]"
        }
    }

    var comparisonHint: String {
        switch self {
        case .standard:
            "Readings match how loud it sounds to you—useful for comparing against noise standards."
        case .highSensitivity:
            "Readings are often higher than standard mode—that is normal; it measures sound you may not hear but is still there."
        }
    }
}

struct ModeVisualTheme {
    let accent: Color
    let secondaryAccent: Color
    let gaugeGradient: [Color]
    let waveformGradient: [Color]
    let waveformLineWidth: CGFloat
    let cardTint: Color
    let badgeForeground: Color
    let badgeBackground: Color

    static func theme(for mode: AcousticMeasurementMode) -> ModeVisualTheme {
        switch mode {
        case .standard:
            ModeVisualTheme(
                accent: Color(red: 0.18, green: 0.55, blue: 0.72),
                secondaryAccent: Color(red: 0.12, green: 0.68, blue: 0.52),
                gaugeGradient: [
                    Color(red: 0.12, green: 0.68, blue: 0.52),
                    Color(red: 0.18, green: 0.55, blue: 0.72),
                    Color(red: 0.22, green: 0.42, blue: 0.78),
                ],
                waveformGradient: [
                    Color(red: 0.12, green: 0.68, blue: 0.52),
                    Color(red: 0.18, green: 0.55, blue: 0.72),
                    Color(red: 0.28, green: 0.45, blue: 0.85),
                ],
                waveformLineWidth: 2,
                cardTint: Color(red: 0.12, green: 0.55, blue: 0.72).opacity(0.08),
                badgeForeground: Color(red: 0.15, green: 0.62, blue: 0.78),
                badgeBackground: Color(red: 0.12, green: 0.55, blue: 0.72).opacity(0.14)
            )
        case .highSensitivity:
            ModeVisualTheme(
                accent: Color(red: 1.0, green: 0.45, blue: 0.12),
                secondaryAccent: Color(red: 0.72, green: 0.35, blue: 0.95),
                gaugeGradient: [
                    Color(red: 1.0, green: 0.45, blue: 0.12),
                    Color(red: 0.95, green: 0.28, blue: 0.55),
                    Color(red: 0.62, green: 0.35, blue: 0.98),
                ],
                waveformGradient: [
                    Color(red: 1.0, green: 0.55, blue: 0.1),
                    Color(red: 0.98, green: 0.32, blue: 0.48),
                    Color(red: 0.68, green: 0.38, blue: 1.0),
                ],
                waveformLineWidth: 2.5,
                cardTint: Color(red: 1.0, green: 0.45, blue: 0.12).opacity(0.1),
                badgeForeground: Color(red: 1.0, green: 0.52, blue: 0.18),
                badgeBackground: Color(red: 0.72, green: 0.35, blue: 0.95).opacity(0.18)
            )
        }
    }
}
