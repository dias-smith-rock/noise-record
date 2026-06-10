import SwiftUI

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
    var mode: AcousticMeasurementMode = .standard

    private var theme: ModeVisualTheme { .theme(for: mode) }
    private var risk: NoiseRiskLevel { .from(db: db, highSensitivity: mode.isHighSensitivity) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(theme.accent.opacity(0.15), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: CGFloat(min(max(db, 0), 120) / 120))
                    .stroke(
                        AngularGradient(
                            colors: theme.gaugeGradient + [theme.gaugeGradient.first ?? theme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: mode.isHighSensitivity ? theme.accent.opacity(0.35) : .clear, radius: 8)
                    .animation(.easeOut(duration: mode.isHighSensitivity ? 0.08 : 0.15), value: db)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", db))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(mode.isHighSensitivity ? theme.accent : .primary)
                    Text(mode.technicalBadge)
                        .font(.caption.bold())
                        .foregroundStyle(theme.accent)
                }
            }
            .frame(width: 200, height: 200)

            Text(risk.label)
                .font(.subheadline)
                .foregroundStyle(risk.color)
                .multilineTextAlignment(.center)

            if mode.isHighSensitivity {
                Text("全频扫描中 · 读数高于标准模式属正常现象")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryAccent)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
