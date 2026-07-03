import SwiftUI

struct SleepMonitorHeaderControl: View {
    @Bindable var coordinator: SleepNoiseMonitorCoordinator
    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    var theme: ModeVisualTheme
    @State private var isStarting = false

    var body: some View {
        if coordinator.isSleepMonitoring {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                sleepCapsule(title: elapsedText, systemImage: "moon.stars.fill", prominent: true)
            }
        } else {
            Button {
                Task { await startSleepMonitoring() }
            } label: {
                sleepCapsule(title: L10n.sleepMonitorHeaderButton, systemImage: "moon.zzz.fill", prominent: false)
            }
            .buttonStyle(.plain)
            .disabled(isStarting)
            .opacity(isStarting ? 0.45 : 1)
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
