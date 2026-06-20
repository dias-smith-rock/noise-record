import SwiftUI

extension NoiseRiskLevel {
    var color: Color {
        switch self {
        case .quiet: .green
        case .moderate: .yellow
        case .loud: .orange
        case .dangerous: .red
        }
    }

    var label: String {
        switch self {
        case .quiet: L10n.noiseRiskQuiet
        case .moderate: L10n.noiseRiskModerate
        case .loud: L10n.noiseRiskLoud
        case .dangerous: L10n.noiseRiskDangerous
        }
    }
}
