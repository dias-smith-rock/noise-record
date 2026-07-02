import SwiftUI

struct SleepActiveBanner: View {
    @Bindable var coordinator: SleepNoiseMonitorCoordinator
    var theme: ModeVisualTheme

    private var elapsedText: String {
        guard let started = coordinator.activeSession?.startedAt else { return "—" }
        return DurationFormatting.hms(from: Date().timeIntervalSince(started))
    }

    var body: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(theme.accent)
                    Text(L10n.sleepActiveTitle)
                        .font(.headline)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(elapsedText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    currentMetric
                    noiseFloorMetric
                    metric(title: L10n.sleepActiveAnomalies, value: Float(coordinator.liveAnomalyCount), suffix: "")
                }
            }
        }
    }

    private var currentMetric: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.sleepActiveCurrent)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if coordinator.liveCurrentDB > 0 {
                Text(String(format: "%.1f dB", coordinator.liveCurrentDB))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(theme.accent)
            } else {
                Text("—")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noiseFloorMetric: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.sleepActiveNoiseFloor)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let floor = coordinator.liveNoiseFloor, floor > 0 {
                Text(String(format: "%.1f dB", floor))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(theme.accent)
            } else {
                Text("—")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(title: String, value: Float, suffix: String = " dB") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if suffix.isEmpty {
                Text("\(Int(value))")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(theme.accent)
            } else {
                Text(String(format: "%.0f%@", value, suffix))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
