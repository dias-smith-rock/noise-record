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

    var userFacingTitle: String { localizedUserFacingTitle }
    var userFacingSubtitle: String { localizedUserFacingSubtitle }
    var segmentLabel: String { localizedSegmentLabel }
    var technicalBadge: String { localizedTechnicalBadge }
    var coreDescription: String { localizedCoreDescription }
    var tooltipCopy: String { localizedTooltipCopy }
    var tooltipHeadline: String { localizedTooltipHeadline }
    var comparisonHint: String { localizedComparisonHint }

    /// 波形图纵向标度（收窄范围以增强视觉起伏）。
    var waveformMinDB: Float {
        switch self {
        case .standard: 30
        case .highSensitivity: 35
        }
    }

    var waveformMaxDB: Float {
        switch self {
        case .standard: 72
        case .highSensitivity: 100
        }
    }
}

/// Restrained palette: one accent per mode, neutral surfaces everywhere else.
struct ModeVisualTheme {
    let accent: Color
    let cardTint: Color
    let waveformLineWidth: CGFloat

    var secondaryAccent: Color { accent.opacity(0.82) }
    var gaugeGradient: [Color] { [accent.opacity(0.4), accent] }
    var waveformGradient: [Color] { [accent.opacity(0.35), accent] }
    var badgeForeground: Color { accent }
    var badgeBackground: Color { accent.opacity(0.12) }
    var surfaceBorder: Color { Color.primary.opacity(0.08) }

    static func builtinAccent(for mode: AcousticMeasurementMode) -> Color {
        switch mode {
        case .standard:
            Color(red: 0.16, green: 0.52, blue: 0.68)
        case .highSensitivity:
            Color(red: 0.90, green: 0.46, blue: 0.14)
        }
    }

    static func builtinTheme(for mode: AcousticMeasurementMode) -> ModeVisualTheme {
        switch mode {
        case .standard:
            ModeVisualTheme(
                accent: builtinAccent(for: .standard),
                cardTint: Color(.secondarySystemGroupedBackground),
                waveformLineWidth: 2
            )
        case .highSensitivity:
            ModeVisualTheme(
                accent: builtinAccent(for: .highSensitivity),
                cardTint: Color(.secondarySystemGroupedBackground),
                waveformLineWidth: 2.25
            )
        }
    }

    static func theme(for mode: AcousticMeasurementMode) -> ModeVisualTheme {
        let base = builtinTheme(for: mode)
        let accent = AppAppearanceSettings.shared.resolvedAccent(for: mode)
        return ModeVisualTheme(
            accent: accent,
            cardTint: base.cardTint,
            waveformLineWidth: base.waveformLineWidth
        )
    }
}
