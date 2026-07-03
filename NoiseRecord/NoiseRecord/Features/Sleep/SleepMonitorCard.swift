import SwiftUI

struct SleepMonitorHeaderMenu: View {
    @Bindable var coordinator: SleepNoiseMonitorCoordinator
    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    var theme: ModeVisualTheme
    var latestCompletedSessionID: UUID?
    var onViewLatestReport: () -> Void
    var onViewHistory: () -> Void
    @State private var isStarting = false

    var body: some View {
        HStack(spacing: 8) {
            if coordinator.isSleepMonitoring {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    sleepCapsule(title: elapsedText, systemImage: "moon.stars.fill", prominent: true)
                }
            }

            ProTabHeaderIconButton(systemImage: "moon.zzz.fill", theme: theme) {
                if !coordinator.isSleepMonitoring {
                    Button {
                        Task { await startSleepMonitoring() }
                    } label: {
                        Label(L10n.sleepMenuStart, systemImage: "bed.double.fill")
                    }
                    .disabled(isStarting)
                }

                if latestCompletedSessionID == nil {
                    Button {} label: {
                        Label(L10n.sleepMenuNoReport, systemImage: "doc.text.fill")
                    }
                    .disabled(true)
                } else {
                    Button(action: onViewLatestReport) {
                        Label(L10n.sleepMenuLatestReport, systemImage: "doc.text.fill")
                    }
                }

                Button(action: onViewHistory) {
                    Label(L10n.sleepMenuHistory, systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .disabled(isStarting && !coordinator.isSleepMonitoring)
        }
    }

    private var elapsedText: String {
        guard let started = coordinator.activeSession?.startedAt else { return "—" }
        return DurationFormatting.hms(from: Date().timeIntervalSince(started))
    }

    private func sleepCapsule(title: String, systemImage: String, prominent: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(prominent ? .white : theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(prominent ? theme.accent : theme.badgeBackground)
        .clipShape(Capsule())
    }

    private func startSleepMonitoring() async {
        isStarting = true
        defer { isStarting = false }
        let started = await coordinator.startSession(isHighSensitivity: engine.isHighSensitivityMode)
        if started {
            audioStateManager.noteMonitoringStarted()
        }
    }
}
