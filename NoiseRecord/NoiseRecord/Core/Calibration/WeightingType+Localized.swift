import Foundation

extension WeightingType {
    var localizedDisplayName: String {
        switch self {
        case .a: AppLocalization.string( "weighting.a.displayName")
        case .c: AppLocalization.string( "weighting.c.displayName")
        case .z: AppLocalization.string( "weighting.z.displayName")
        }
    }

    var displayName: String { localizedDisplayName }
}
