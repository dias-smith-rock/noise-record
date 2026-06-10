import SwiftUI

enum NoiseRiskLevel: Sendable {
    case quiet
    case moderate
    case loud
    case dangerous

    static func from(db: Float) -> NoiseRiskLevel {
        switch db {
        case ..<40: .quiet
        case 40..<60: .moderate
        case 60..<80: .loud
        default: .dangerous
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

    var label: String {
        switch self {
        case .quiet: "安静（如悄悄话）"
        case .moderate: "适中（如普通谈话）"
        case .loud: "偏吵（如繁忙马路）"
        case .dangerous: "危险（长期有损听力）"
        }
    }
}

struct NoiseLevelGauge: View {
    let db: Float

    private var risk: NoiseRiskLevel { .from(db: db) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(risk.color.opacity(0.2), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(db, 0), 120) / 120))
                    .stroke(risk.color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.15), value: db)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", db))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("dB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)

            Text(risk.label)
                .font(.subheadline)
                .foregroundStyle(risk.color)
                .multilineTextAlignment(.center)
        }
    }
}
