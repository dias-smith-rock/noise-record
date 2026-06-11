import Foundation

extension WeightingType {
    var localizedDisplayName: String {
        switch self {
        case .a: String(localized: "weighting.a.displayName")
        case .c: String(localized: "weighting.c.displayName")
        case .z: String(localized: "weighting.z.displayName")
        }
    }
}
