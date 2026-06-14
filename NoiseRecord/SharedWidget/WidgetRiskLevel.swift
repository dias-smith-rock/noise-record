import SwiftUI

enum WidgetRiskLevel: Sendable {
    case quiet
    case moderate
    case loud
    case dangerous

    static func from(db: Float, highSensitivity: Bool) -> WidgetRiskLevel {
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

    var color: Color {
        switch self {
        case .quiet: .green
        case .moderate: .yellow
        case .loud: .orange
        case .dangerous: .red
        }
    }
}

enum WidgetTheme {
    static func accent(highSensitivity: Bool) -> Color {
        if highSensitivity {
            Color(red: 0.90, green: 0.46, blue: 0.14)
        } else {
            Color(red: 0.16, green: 0.52, blue: 0.68)
        }
    }

    static func gaugeGradient(highSensitivity: Bool) -> [Color] {
        let accent = accent(highSensitivity: highSensitivity)
        return [accent.opacity(0.4), accent]
    }
}
