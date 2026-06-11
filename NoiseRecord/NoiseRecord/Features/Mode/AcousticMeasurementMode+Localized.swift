import Foundation

extension AcousticMeasurementMode {
    var localizedUserFacingTitle: String {
        switch self {
        case .standard: AppLocalization.string("mode.standard.userFacingTitle")
        case .highSensitivity: AppLocalization.string("mode.highSensitivity.userFacingTitle")
        }
    }

    var localizedUserFacingSubtitle: String {
        switch self {
        case .standard: AppLocalization.string( "mode.standard.userFacingSubtitle")
        case .highSensitivity: AppLocalization.string( "mode.highSensitivity.userFacingSubtitle")
        }
    }

    var localizedSegmentLabel: String {
        switch self {
        case .standard: AppLocalization.string( "mode.standard.segmentLabel")
        case .highSensitivity: AppLocalization.string( "mode.highSensitivity.segmentLabel")
        }
    }

    var localizedTechnicalBadge: String {
        switch self {
        case .standard: AppLocalization.string( "mode.standard.technicalBadge")
        case .highSensitivity: AppLocalization.string( "mode.highSensitivity.technicalBadge")
        }
    }

    var localizedCoreDescription: String {
        switch self {
        case .standard: AppLocalization.string( "mode.standard.coreDescription")
        case .highSensitivity: AppLocalization.string( "mode.highSensitivity.coreDescription")
        }
    }

    var localizedTooltipCopy: String {
        switch self {
        case .standard: AppLocalization.string( "mode.standard.tooltipCopy")
        case .highSensitivity: AppLocalization.string( "mode.highSensitivity.tooltipCopy")
        }
    }

    var localizedTooltipHeadline: String {
        switch self {
        case .standard: AppLocalization.string( "mode.standard.tooltipHeadline")
        case .highSensitivity: AppLocalization.string( "mode.highSensitivity.tooltipHeadline")
        }
    }

    var localizedComparisonHint: String {
        switch self {
        case .standard: AppLocalization.string( "mode.standard.comparisonHint")
        case .highSensitivity: AppLocalization.string( "mode.highSensitivity.comparisonHint")
        }
    }
}
