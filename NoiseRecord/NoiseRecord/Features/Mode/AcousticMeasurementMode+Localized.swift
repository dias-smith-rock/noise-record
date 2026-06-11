import Foundation

extension AcousticMeasurementMode {
    var localizedUserFacingTitle: String {
        switch self {
        case .standard: String(localized: "mode.standard.userFacingTitle")
        case .highSensitivity: String(localized: "mode.highSensitivity.userFacingTitle")
        }
    }

    var localizedUserFacingSubtitle: String {
        switch self {
        case .standard: String(localized: "mode.standard.userFacingSubtitle")
        case .highSensitivity: String(localized: "mode.highSensitivity.userFacingSubtitle")
        }
    }

    var localizedSegmentLabel: String {
        switch self {
        case .standard: String(localized: "mode.standard.segmentLabel")
        case .highSensitivity: String(localized: "mode.highSensitivity.segmentLabel")
        }
    }

    var localizedTechnicalBadge: String {
        switch self {
        case .standard: String(localized: "mode.standard.technicalBadge")
        case .highSensitivity: String(localized: "mode.highSensitivity.technicalBadge")
        }
    }

    var localizedCoreDescription: String {
        switch self {
        case .standard: String(localized: "mode.standard.coreDescription")
        case .highSensitivity: String(localized: "mode.highSensitivity.coreDescription")
        }
    }

    var localizedTooltipCopy: String {
        switch self {
        case .standard: String(localized: "mode.standard.tooltipCopy")
        case .highSensitivity: String(localized: "mode.highSensitivity.tooltipCopy")
        }
    }

    var localizedTooltipHeadline: String {
        switch self {
        case .standard: String(localized: "mode.standard.tooltipHeadline")
        case .highSensitivity: String(localized: "mode.highSensitivity.tooltipHeadline")
        }
    }

    var localizedComparisonHint: String {
        switch self {
        case .standard: String(localized: "mode.standard.comparisonHint")
        case .highSensitivity: String(localized: "mode.highSensitivity.comparisonHint")
        }
    }
}
