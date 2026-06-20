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
        case .quiet: L10n.noiseRiskQuiet
        case .moderate: L10n.noiseRiskModerate
        case .loud: L10n.noiseRiskLoud
        case .dangerous: L10n.noiseRiskDangerous
        }
    }
}

struct NoiseLevelGauge: View {
    let db: Float
    var mode: AcousticMeasurementMode = .standard
    var humidityText: String = "--"
    var temperatureText: String = "--"
    var onFullscreenTap: (() -> Void)?

    private var theme: ModeVisualTheme { .theme(for: mode) }
    private var risk: NoiseRiskLevel { .from(db: db, highSensitivity: mode.isHighSensitivity) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                gaugeCircle
                    .frame(width: 200, height: 200)
                    .frame(maxWidth: .infinity)

                if let onFullscreenTap {
                    Button(action: onFullscreenTap) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(theme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.dashboardFullscreenLED)
                }
            }

            HStack(spacing: 18) {
                EnvironmentInlineMetric(
                    symbol: "drop.fill",
                    text: humidityText,
                    tint: Color(red: 0.35, green: 0.68, blue: 0.92)
                )

                Text(risk.label)
                    .font(.subheadline)
                    .foregroundStyle(risk.color)
                    .multilineTextAlignment(.center)

                EnvironmentInlineMetric(
                    symbol: "thermometer.medium",
                    text: temperatureText,
                    tint: Color(red: 0.95, green: 0.55, blue: 0.28)
                )
            }
            .frame(maxWidth: .infinity)

            if mode.isHighSensitivity {
                Text(L10n.gaugeHighSensitivityHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var gaugeCircle: some View {
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
                .animation(.linear(duration: 0.08), value: (db * 2).rounded() / 2)

            VStack(spacing: 4) {
                Text(String(format: "%.1f", db))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(mode.technicalBadge)
                    .font(.caption.bold())
                    .foregroundStyle(theme.accent)
            }
        }
    }
}

private struct EnvironmentInlineMetric: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
