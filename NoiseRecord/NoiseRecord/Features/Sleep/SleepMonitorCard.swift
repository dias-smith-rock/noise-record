import SwiftUI

struct SleepMonitorCard: View {
    @Bindable var coordinator: SleepNoiseMonitorCoordinator
    @Bindable var engine: NoiseMonitorEngine
    var theme: ModeVisualTheme
    @State private var isStarting = false
    @State private var sleepMeasurementMode: AcousticMeasurementMode = .highSensitivity

    private var cardTheme: ModeVisualTheme {
        .theme(for: sleepMeasurementMode)
    }

    var body: some View {
        ProCard(theme: cardTheme) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundStyle(cardTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.sleepMonitorTitle)
                            .font(.headline)
                        Text(L10n.sleepMonitorSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(L10n.sleepMonitorPowerHint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                ModeSwitchView(mode: $sleepMeasurementMode, isMonitoring: coordinator.isSleepMonitoring)

                Text(L10n.sleepMonitorModeHint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Button {
                    Task { await startSleepMonitoring() }
                } label: {
                    Label(L10n.sleepMonitorStart, systemImage: "bed.double.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(cardTheme.accent)
                .disabled(isStarting || coordinator.isSleepMonitoring)
            }
        }
    }

    private func startSleepMonitoring() async {
        isStarting = true
        defer { isStarting = false }
        _ = await coordinator.startSession(isHighSensitivity: sleepMeasurementMode.isHighSensitivity)
    }
}
