import SwiftUI
import WidgetKit

private enum LiveActivityPalette {
    static let background = Color(red: 0.02, green: 0.05, blue: 0.09)
    static let label = Color.white.opacity(0.62)
    static let primaryText = Color.white
}

struct NoiseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoiseMonitorAttributes.self) { context in
            LockScreenNoiseActivityView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(LiveActivityPalette.background)
            .activitySystemActionForegroundColor(LiveActivityPalette.primaryText)
            .widgetURL(LiveActivityDeepLink.monitorURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityWaveformBars(
                        levels: context.state.waveformLevels,
                        accentHex: LiveActivityStyle.decibelColorHex(
                            for: context.state.currentDecibel,
                            highSensitivity: context.attributes.isHighSensitivityMode
                        )
                    )
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.weightingLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(LiveActivityPalette.label)
                        decibelText(context.state.currentDecibel, size: 28, attributes: context.attributes)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.noiseLevelDescription)
                        .font(.caption.bold())
                        .foregroundStyle(LiveActivityPalette.primaryText)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.attributes.measurementModeName)
                            .font(.caption2.bold())
                            .foregroundStyle(LiveActivityPalette.label)
                        Text(context.state.statusMessage)
                            .font(.caption)
                            .foregroundStyle(LiveActivityPalette.label)
                            .lineLimit(2)
                        Link(destination: LiveActivityDeepLink.monitorURL) {
                            Label("Open DecibelPro", systemImage: "waveform")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.16, green: 0.52, blue: 0.68))
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .foregroundStyle(Color(hex: LiveActivityStyle.decibelColorHex(
                        for: context.state.currentDecibel,
                        highSensitivity: context.attributes.isHighSensitivityMode
                    )))
            } compactTrailing: {
                Text(String(format: "%.0fdB", context.state.currentDecibel))
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: LiveActivityStyle.decibelColorHex(
                        for: context.state.currentDecibel,
                        highSensitivity: context.attributes.isHighSensitivityMode
                    )))
            } minimal: {
                Text(String(format: "%.0f", context.state.currentDecibel))
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: LiveActivityStyle.decibelColorHex(
                        for: context.state.currentDecibel,
                        highSensitivity: context.attributes.isHighSensitivityMode
                    )))
            }
            .widgetURL(LiveActivityDeepLink.monitorURL)
        }
    }

    @ViewBuilder
    private func decibelText(_ value: Float, size: CGFloat, attributes: NoiseMonitorAttributes) -> some View {
        Text(String(format: "%.1f dB", value))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color(hex: LiveActivityStyle.decibelColorHex(
                for: value,
                highSensitivity: attributes.isHighSensitivityMode
            )))
    }
}

private struct LockScreenNoiseActivityView: View {
    let attributes: NoiseMonitorAttributes
    let state: NoiseMonitorAttributes.ContentState

    private var highSensitivity: Bool {
        attributes.isHighSensitivityMode
    }

    var body: some View {
        HStack(spacing: 14) {
            LiveActivityWaveformBars(
                levels: state.waveformLevels,
                accentHex: LiveActivityStyle.decibelColorHex(for: state.currentDecibel, highSensitivity: highSensitivity)
            )
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: "%.1f dB", state.currentDecibel))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: LiveActivityStyle.decibelColorHex(
                        for: state.currentDecibel,
                        highSensitivity: highSensitivity
                    )))
                Text(state.statusMessage)
                    .font(.caption)
                    .foregroundStyle(LiveActivityPalette.label)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(state.noiseLevelDescription)
                        .font(.caption2.bold())
                        .foregroundStyle(LiveActivityPalette.primaryText)
                    Text(state.weightingLabel)
                        .font(.caption2)
                        .foregroundStyle(LiveActivityPalette.label)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LiveActivityPalette.background)
    }
}

private struct LiveActivityWaveformBars: View {
    let levels: [Float]
    let accentHex: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(displayLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: accentHex).opacity(0.85))
                    .frame(width: 5, height: 8 + 22 * CGFloat(level))
            }
        }
        .frame(height: 32, alignment: .bottom)
    }

    private var displayLevels: [Float] {
        var bars = levels
        while bars.count < 5 { bars.insert(0.12, at: 0) }
        if bars.count > 5 { bars = Array(bars.suffix(5)) }
        return bars
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
