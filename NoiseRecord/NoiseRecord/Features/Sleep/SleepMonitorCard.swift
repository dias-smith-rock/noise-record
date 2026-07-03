import SwiftUI

struct SleepMonitorHeaderControl: View {
    @Bindable var coordinator: SleepNoiseMonitorCoordinator
    var theme: ModeVisualTheme
    @State private var isStarting = false

    var body: some View {
        if coordinator.isSleepMonitoring {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                sleepCapsule(title: elapsedText, systemImage: "moon.stars.fill", prominent: true)
            }
        } else {
            Menu {
                Button {
                    Task { await startSleepMonitoring(isHighSensitivity: true) }
                } label: {
                    Text(AcousticMeasurementMode.highSensitivity.userFacingTitle)
                }
                Button {
                    Task { await startSleepMonitoring(isHighSensitivity: false) }
                } label: {
                    Text(AcousticMeasurementMode.standard.userFacingTitle)
                }
            } label: {
                sleepCapsule(title: L10n.sleepMonitorHeaderButton, systemImage: "moon.zzz.fill", prominent: false)
            }
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

    private func startSleepMonitoring(isHighSensitivity: Bool) async {
        isStarting = true
        defer { isStarting = false }
        _ = await coordinator.startSession(isHighSensitivity: isHighSensitivity)
    }
}
