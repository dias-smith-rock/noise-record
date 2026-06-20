import SwiftUI

struct WatchMonitorView: View {
    @State private var engine = WatchNoiseMonitorEngine()
    @State private var runtime = WatchExtendedRuntimeManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                decibelPanel
                statsRow
                modePicker
                controlButton

                if let error = engine.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if let notice = engine.runtimeNotice {
                    Text(notice)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                if engine.isMonitoring {
                    Text(WatchL10n.batteryNotice)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(WatchL10n.disclaimer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(WatchL10n.appTitle)
        .onAppear {
            runtime.onInvalidated = { message in
                engine.handleRuntimeInvalidation(message, runtime: runtime)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(engine.weightingBadge)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Text(riskLabel)
                .font(.caption.bold())
                .foregroundStyle(riskColor)
        }
    }

    private var decibelPanel: some View {
        let hex = DecibelColorStyle.colorHex(for: engine.currentDB, highSensitivity: engine.isHighSensitivityMode)
        return VStack(spacing: 2) {
            Text(String(format: "%.1f", engine.currentDB))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(hex: hex))
            Text(engine.weightingBadge)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCell(title: WatchL10n.max, value: engine.maxDB)
            statCell(title: WatchL10n.min, value: engine.minDB)
            statCell(title: WatchL10n.avg, value: engine.averageDB)
            statCell(title: WatchL10n.leq, value: engine.leq)
        }
    }

    private func statCell(title: String, value: Float) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f", value))
                .font(.caption.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var modePicker: some View {
        VStack(spacing: 6) {
            Text(WatchL10n.modeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                modeOptionButton(
                    title: WatchL10n.standardMode,
                    isSelected: !engine.isHighSensitivityMode
                ) {
                    engine.isHighSensitivityMode = false
                }

                modeOptionButton(
                    title: WatchL10n.highSensitivityMode,
                    isSelected: engine.isHighSensitivityMode
                ) {
                    engine.isHighSensitivityMode = true
                }
            }
        }
        .disabled(engine.isMonitoring)
        .opacity(engine.isMonitoring ? 0.55 : 1)
    }

    private func modeOptionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(isSelected ? .green : .secondary)
    }

    private var controlButton: some View {
        Button {
            Task { await toggleMonitoring() }
        } label: {
            Label(
                engine.isMonitoring ? WatchL10n.stop : WatchL10n.start,
                systemImage: engine.isMonitoring ? "stop.circle.fill" : "play.circle.fill"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(engine.isMonitoring ? .red : .green)
    }

    private var riskLabel: String {
        switch engine.riskLevel {
        case .quiet: WatchL10n.riskQuiet
        case .moderate: WatchL10n.riskModerate
        case .loud: WatchL10n.riskLoud
        case .dangerous: WatchL10n.riskDangerous
        }
    }

    private var riskColor: Color {
        switch engine.riskLevel {
        case .quiet: .green
        case .moderate: .yellow
        case .loud: .orange
        case .dangerous: .red
        }
    }

    private func toggleMonitoring() async {
        if engine.isMonitoring {
            engine.stopMonitoring(runtime: runtime)
        } else {
            await engine.requestPermissionAndStart(runtime: runtime)
        }
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
