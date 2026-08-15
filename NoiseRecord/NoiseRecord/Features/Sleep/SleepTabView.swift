import SwiftData
import SwiftUI

/// Primary Sleep tab: overnight monitoring, morning report, and history.
struct SleepTabView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    @Bindable var sleepCoordinator: SleepNoiseMonitorCoordinator
    let isTabActive: Bool
    var onOpenLive: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var environment = AmbientEnvironmentProvider()
    @State private var latestCompletedSessionID: UUID?
    @State private var isStarting = false

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: L10n.tabSleep, theme: theme)

            ScrollView {
                if isTabActive {
                    VStack(spacing: 20) {
                        ModeStatusBadgeView(mode: measurementMode)

                        OvernightMonitoringSection(
                            theme: theme,
                            isSleepMonitoring: sleepCoordinator.isSleepMonitoring,
                            canStartOvernight: canStartOvernight,
                            sleepMonitoringStartedAt: sleepCoordinator.activeSession?.startedAt,
                            hasLatestReport: latestCompletedSessionID != nil,
                            onStart: startSleepMonitoring,
                            onOpenReport: openLatestMorningReport,
                            onOpenHistory: openSleepHistory
                        )

                        if sleepCoordinator.isSleepMonitoring {
                            stopSessionCard
                        }

                        Text(L10n.sleepTabFooter)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
        .observesAppLanguage()
        .debugView("tab.sleep")
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .onAppear {
            environment.startUpdating()
            refreshLatestSleepSession()
        }
        .onDisappear {
            environment.stopUpdating()
        }
        .onChange(of: isTabActive) { _, active in
            if active {
                refreshLatestSleepSession()
            }
        }
        .onChange(of: sleepCoordinator.showReportSheet) { _, isPresented in
            if !isPresented {
                refreshLatestSleepSession()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: SleepNotificationRouter.sleepMonitoringStartedFromNotification
            )
        ) { _ in
            refreshLatestSleepSession()
        }
    }

    private var canStartOvernight: Bool {
        !sleepCoordinator.isSleepMonitoring
            && !(engine.isMonitoring && !sleepCoordinator.isSleepMonitoring)
            && !isStarting
            && audioStateManager.appAudioState != .playing
    }

    private var stopSessionCard: some View {
        Button {
            AppTelemetry.logProductEvent(
                "monitor_fab_tap",
                parameters: ["action": "sleep_end", "source": "sleep_tab"]
            )
            AdSceneLifecycle.recordFirstInteraction(source: "sleep_tab_stop")
            Task {
                await sleepCoordinator.endSession(
                    environment: SleepEnvironmentSnapshot(
                        temperatureCelsius: environment.temperatureCelsius,
                        humidityPercent: environment.humidityPercent,
                        latitude: environment.latitude ?? engine.evidenceLatitude,
                        longitude: environment.longitude ?? engine.evidenceLongitude
                    )
                )
                audioStateManager.noteMonitoringStopped()
            }
        } label: {
            Label(L10n.sleepEndSession, systemImage: "stop.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    private func startSleepMonitoring() async {
        guard canStartOvernight else { return }
        isStarting = true
        defer { isStarting = false }

        AppTelemetry.logProductEvent(
            "sleep_start_tap",
            parameters: [
                "mode": engine.isHighSensitivityMode ? "high_sensitivity" : "standard",
                "source": "sleep_tab",
            ]
        )
        AdSceneLifecycle.recordFirstInteraction(source: "sleep_tab_start")

        let started = await sleepCoordinator.startSession(
            isHighSensitivity: engine.isHighSensitivityMode,
            environment: SleepEnvironmentSnapshot(
                temperatureCelsius: environment.temperatureCelsius,
                humidityPercent: environment.humidityPercent,
                latitude: environment.latitude ?? engine.evidenceLatitude,
                longitude: environment.longitude ?? engine.evidenceLongitude
            )
        )
        if started {
            audioStateManager.noteMonitoringStarted()
            onOpenLive?()
        }
    }

    private func openLatestMorningReport() {
        guard let sessionID = latestCompletedSessionID else { return }
        sleepCoordinator.presentReport(sessionID: sessionID, source: "sleep_tab")
    }

    private func openSleepHistory() {
        AppTelemetry.logProductEvent(
            "sleep_history_open",
            parameters: [
                "gated": "false",
                "source": "sleep_tab",
            ]
        )
        sleepCoordinator.presentHistory()
    }

    private func refreshLatestSleepSession() {
        var descriptor = FetchDescriptor<SleepNoiseSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        latestCompletedSessionID = try? modelContext.fetch(descriptor).first?.id
    }
}
