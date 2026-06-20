import Foundation

enum NoiseRiskLevel: Sendable {
    case quiet
    case moderate
    case loud
    case dangerous

    static func from(db: Float, highSensitivity: Bool) -> NoiseRiskLevel {
        if highSensitivity {
            switch db {
            case ..<45: .quiet
            case 45..<65: .moderate
            case 65..<85: .loud
            default: .dangerous
            }
        } else {
            switch db {
            case ..<40: .quiet
            case 40..<60: .moderate
            case 60..<80: .loud
            default: .dangerous
            }
        }
    }
}

enum DecibelColorStyle {
    static func colorHex(for db: Float, highSensitivity: Bool) -> String {
        let quietLimit: Float = highSensitivity ? 45 : 40
        let moderateLimit: Float = highSensitivity ? 65 : 60
        let loudLimit: Float = highSensitivity ? 85 : 80

        switch db {
        case ..<quietLimit: return "34C759"
        case ..<moderateLimit: return "FFD60A"
        case ..<loudLimit: return "FF9500"
        default: return "FF3B30"
        }
    }
}
