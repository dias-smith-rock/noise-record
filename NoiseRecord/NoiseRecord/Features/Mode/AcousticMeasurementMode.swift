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

    static func theme(for mode: AcousticMeasurementMode) -> ModeVisualTheme {
        switch mode {
        case .standard:
            ModeVisualTheme(
                accent: Color(red: 0.16, green: 0.52, blue: 0.68),
                cardTint: Color(.secondarySystemGroupedBackground),
                waveformLineWidth: 2
            )
        case .highSensitivity:
            ModeVisualTheme(
                accent: Color(red: 0.90, green: 0.46, blue: 0.14),
                cardTint: Color(.secondarySystemGroupedBackground),
                waveformLineWidth: 2.25
            )
        }
    }
}
