import SwiftData
import SwiftUI

struct DashboardView: View {
    private static let showsReportAndCSVExport = false
    private static let measurementPersistInterval: TimeInterval = 5

    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    @Bindable var sleepCoordinator: SleepNoiseMonitorCoordinator
    @Bindable private var appearance = AppAppearanceSettings.shared
    let isTabActive: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var shareReport: SilenceRatingReport?
    @State private var showReportSheet = false
    @State private var csvShareURL: URL?
    @State private var showCSVShare = false
    @State private var csvExportErrorMessage: String?
    @State private var measurementPersistTick = 0
    @State private var isFullScreenPresented = false
    @State private var showsFullscreenLEDGuide = false
    @State private var fullscreenButtonFrame: CGRect = .zero
    @State private var environment = AmbientEnvironmentProvider()
    @State private var showLocationWeatherPermissionDenied = false
    @State private var showLocationAccessGuide = false
    @State private var hasScheduledLocationPermissionPrompt = false
    @State private var waveformReferenceLimitDB = NoiseReferenceLimits.residentialNightDB
    @State private var latestCompletedSessionID: UUID?

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        let _ = appearance.temperatureUnitPreference

        VStack(spacing: 0) {
            ProTabHeader(title: L10n.dashboardTitle, theme: theme) {
                SleepMonitorHeaderMenu(
                    isSleepMonitoring: sleepCoordinator.isSleepMonitoring,
                    isGeneralMonitoringActive: engine.isMonitoring && !sleepCoordinator.isSleepMonitoring,
                    sleepMonitoringStartedAt: sleepCoordinator.activeSession?.startedAt,
                    latestCompletedSessionID: latestCompletedSessionID,
                    measurementMode: measurementMode,
                    onViewLatestReport: openLatestMorningReport,
                    onViewHistory: openSleepHistory,
                    onStartSleepMonitoring: startSleepMonitoringFromHeader
                )
                .equatable()
            }

            ScrollView {
                if isTabActive {
                    dashboardContent
                }
            }
        }
        .observesAppLanguage()
        .onAppear {
            LaunchPerformance.mark(.launchFirstInteractive)
            environment.startUpdating()
            refreshFullscreenLEDGuideVisibility()
            waveformReferenceLimitDB = NoiseReferenceLimits.residentialNightDB
            refreshLatestSleepSession()
            scheduleLocationPermissionPromptIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchAutoStartMonitoring)) { _ in
            scheduleLocationPermissionPromptIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NoiseReferenceLimits.didChangeNotification)) { _ in
            waveformReferenceLimitDB = NoiseReferenceLimits.residentialNightDB
        }
        .onChange(of: isTabActive) { _, isActive in
            refreshFullscreenLEDGuideVisibility()
            if isActive {
                refreshLatestSleepSession()
                Task { @MainActor in
                    await waitForLaunchPresentationToFinish()
                    presentLocationPermissionPromptIfNeeded()
                }
            }
        }
        .onChange(of: sleepCoordinator.showReportSheet) { _, isPresented in
            if !isPresented {
                refreshLatestSleepSession()
            }
        }
        .onDisappear {
            environment.stopUpdating()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProFloatingActionButton(
                title: monitorActionTitle,
                systemImage: monitorActionSymbol,
                theme: theme,
                isDestructive: isMonitorFABShowingStop
            ) {
                guard audioStateManager.appAudioState != .playing else { return }
                AdSceneLifecycle.recordFirstInteraction(source: "monitor_toggle")
                if sleepCoordinator.isSleepMonitoring {
                    AppTelemetry.logProductEvent(
                        "monitor_fab_tap",
                        parameters: ["action": "sleep_end"]
                    )
                } else {
                    AppTelemetry.logProductEvent(
                        "monitor_fab_tap",
                        parameters: [
                            "action": audioStateManager.appAudioState == .monitoring ? "stop" : "start",
                        ]
                    )
                }
                Task {
                    switch audioStateManager.appAudioState {
                    case .monitoring:
                        handleStopMonitoringTapped()
                    case .idle:
                        await audioStateManager.manuallyResumeMonitoring()
                    case .playing:
                        break
                    }
                }
            }
            .disabled(audioStateManager.appAudioState == .playing)
            .opacity(audioStateManager.appAudioState == .playing ? 0.5 : 1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .task(id: engine.isMonitoring) {
            guard engine.isMonitoring, !engine.isSleepModeActive else { return }
            while !Task.isCancelled, engine.isMonitoring {
                try? await Task.sleep(for: .seconds(Self.measurementPersistInterval))
                guard engine.isMonitoring else { break }
                persistMeasurementSample()
            }
        }
        .sheet(isPresented: $showReportSheet) {
            if let report = shareReport {
                ShareReportSheet(report: report)
            }
        }
        .sheet(isPresented: $showCSVShare) {
            if let csvShareURL {
                ShareSheet(items: [csvShareURL])
            }
        }
        .alert(L10n.errorTitle, isPresented: .constant(engine.errorMessage != nil)) {
            Button(L10n.ok) { engine.errorMessage = nil }
        } message: {
            Text(engine.errorMessage ?? "")
        }
        .permissionDeniedAlert(
            isPresented: $engine.showMicrophonePermissionDenied,
            title: L10n.permissionMicrophoneDeniedTitle,
            message: L10n.permissionMicrophoneDeniedMessage
        )
        .alert(L10n.permissionLocationWeatherDeniedTitle, isPresented: $showLocationWeatherPermissionDenied) {
            Button(L10n.permissionOpenSettings) {
                #if targetEnvironment(simulator)
                showLocationAccessGuide = true
                #else
                PermissionSettings.openAppSettings()
                #endif
            }
            Button(L10n.cancel, role: .cancel) {
                LocationWeatherPermissionPromptStore.markPromptDismissed()
            }
        } message: {
            Text(L10n.permissionLocationWeatherDeniedMessage)
        }
        .sheet(isPresented: $showLocationAccessGuide) {
            LocationAccessGuideSheet()
        }
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { csvExportErrorMessage != nil },
            set: { if !$0 { csvExportErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { csvExportErrorMessage = nil }
        } message: {
            Text(csvExportErrorMessage ?? "")
        }
        .fullScreenCover(isPresented: $isFullScreenPresented) {
            FullscreenLEDView(
                engine: engine,
                audioStateManager: audioStateManager,
                environment: environment,
                mode: measurementMode,
                onClose: { isFullScreenPresented = false }
            )
        }
        .onChange(of: isFullScreenPresented) { _, isPresented in
            if isPresented {
                AppReviewStore.isFullscreenLEDBusy = true
                AppTelemetry.logProductEvent(
                    "fullscreen_led_open",
                    parameters: ["mode": measurementMode.rawValue]
                )
                AppReviewStore.noteCoreFeatureUsed(.fullscreenLED)
                InterfaceOrientationLocker.enterLandscapeFullscreen()
                AdSceneLifecycle.showInterstitialOnFullscreenEnter()
            } else {
                AppTelemetry.logProductEvent("fullscreen_led_close")
                InterfaceOrientationLocker.exitLandscapeFullscreen()
                InterfaceOrientationLocker.scheduleAfterPortraitRestored {
                    AppReviewStore.isFullscreenLEDBusy = false
                    NotificationCenter.default.post(
                        name: AppReviewStore.shouldReevaluatePromptNotification,
                        object: nil
                    )
                }
            }
        }
        .onPreferenceChange(FullscreenGuideButtonFrameKey.self) { frame in
            fullscreenButtonFrame = frame
        }
        .overlay {
            if showsFullscreenLEDGuide, fullscreenButtonFrame.width > 0 {
                FullscreenLEDGuideOverlay(
                    theme: theme,
                    buttonFrame: fullscreenButtonFrame,
                    onDismiss: { dismissFullscreenLEDGuide(method: "tap_scrim") },
                    onGuideDismiss: { dismissFullscreenLEDGuide(method: "got_it") },
                    onFullscreenTap: {
                        dismissFullscreenLEDGuide(method: "tap_button")
                        HotStartAdManager.shared.loadAd()
                        isFullScreenPresented = true
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showsFullscreenLEDGuide)
    }

    private var dashboardContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.dashboardSpectrum)
                    .font(.headline)
                SpectrumChartView(
                    spectrum: engine.latestSpectrum,
                    isActive: engine.isMonitoring
                )
                .equatable()
                .frame(height: 180)
            }

            EngineModeSwitchView(engine: engine)
                .disabled(sleepCoordinator.isSleepMonitoring)
                .opacity(sleepCoordinator.isSleepMonitoring ? 0.45 : 1)

            NoiseLevelGauge(
                db: engine.currentDB,
                mode: measurementMode,
                humidityText: environment.humidityDisplay,
                temperatureText: environment.temperatureDisplay,
                hidesFullscreenButton: showsFullscreenLEDGuide,
                onFullscreenTap: {
                    dismissFullscreenLEDGuide()
                    HotStartAdManager.shared.loadAd()
                    isFullScreenPresented = true
                }
            )

            HStack(spacing: 12) {
                StatCard(title: L10n.dashboardMax, value: engine.maxDB, theme: theme)
                StatCard(title: L10n.dashboardMin, value: engine.minDB, theme: theme)
                StatCard(title: L10n.dashboardAvg, value: engine.averageDB, theme: theme)
                StatCard(title: L10n.dashboardLeq, value: engine.leq, theme: theme)
            }

            if engine.isMonitoring {
                ProRecordingStatusBadge(state: engine.recordingState, theme: theme)
            }

            if let label = engine.latestNoiseLabel, engine.aiClassificationEnabled {
                HStack {
                    Image(systemName: "waveform.badge.magnifyingglass")
                    Text(L10n.dashboardDetected(label, confidence: Int(engine.latestNoiseConfidence * 100)))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.dashboardWaveform)
                        .font(.headline)
                    if measurementMode.isHighSensitivity {
                        Text(L10n.dashboardFullBand)
                            .font(.caption2.bold())
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(theme.badgeBackground)
                            .clipShape(Capsule())
                    }
                }
                WaveformView(
                    samples: engine.history,
                    mode: measurementMode,
                    referenceLimitDB: waveformReferenceLimitDB
                )
                    .equatable()
                    .frame(height: 120)

                Text(L10n.dashboardWaveformReferenceCaption(limit: Int(waveformReferenceLimitDB)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(footerNote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if Self.showsReportAndCSVExport {
                HStack(spacing: 12) {
                    Button(L10n.dashboardReport) {
                        shareReport = SilenceRatingReport(
                            leq: engine.leq,
                            maxDB: engine.maxDB,
                            minDB: engine.minDB,
                            averageDB: engine.averageDB,
                            weighting: engine.effectiveWeighting
                        )
                        showReportSheet = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!engine.isMonitoring && engine.leq == 0)

                    Button(L10n.dashboardExportCSV) {
                        exportCSV()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }

    private var isMonitorFABShowingStop: Bool {
        sleepCoordinator.isSleepMonitoring || audioStateManager.appAudioState == .monitoring
    }

    private var monitorActionTitle: String {
        if sleepCoordinator.isSleepMonitoring {
            return L10n.sleepEndSession
        }
        switch audioStateManager.appAudioState {
        case .monitoring: return L10n.dashboardStop
        case .idle: return L10n.dashboardStart
        case .playing: return L10n.dashboardPlayingPlaceholder
        }
    }

    private var monitorActionSymbol: String {
        if isMonitorFABShowingStop {
            return "stop.circle.fill"
        }
        switch audioStateManager.appAudioState {
        case .monitoring: return "stop.circle.fill"
        case .idle: return "play.circle.fill"
        case .playing: return "speaker.wave.2.fill"
        }
    }

    private func handleStopMonitoringTapped() {
        if sleepCoordinator.isSleepMonitoring {
            Task {
                await sleepCoordinator.endSession()
                audioStateManager.noteMonitoringStopped()
                refreshLatestSleepSession()
            }
            return
        }
        audioStateManager.stopMonitoringManually()
    }

    private func refreshLatestSleepSession() {
        latestCompletedSessionID = SleepMeasurementPersistence
            .latestCompletedSession(in: modelContext)?
            .id
    }

    private func openLatestMorningReport() {
        guard let sessionID = latestCompletedSessionID else { return }
        sleepCoordinator.presentReport(sessionID: sessionID, source: "header_menu")
    }

    private func openSleepHistory() {
        let gated = !SubscriptionManager.shared.canAccessSleepHistory
        AppTelemetry.logProductEvent(
            "sleep_history_open",
            parameters: ["gated": gated ? "true" : "false"]
        )
        if SubscriptionManager.shared.canAccessSleepHistory {
            sleepCoordinator.presentHistory()
        } else {
            PaywallPresenter.shared.present(context: .sleepHistory)
        }
    }

    private func startSleepMonitoringFromHeader() async {
        AppTelemetry.logProductEvent(
            "sleep_start_tap",
            parameters: [
                "mode": engine.isHighSensitivityMode ? "high_sensitivity" : "standard",
            ]
        )
        let started = await sleepCoordinator.startSession(isHighSensitivity: engine.isHighSensitivityMode)
        if started {
            audioStateManager.noteMonitoringStarted()
        }
    }

    private func scheduleLocationPermissionPromptIfNeeded() {
        guard isTabActive else { return }
        guard !hasScheduledLocationPermissionPrompt else { return }
        hasScheduledLocationPermissionPrompt = true

        Task { @MainActor in
            await waitForLaunchPresentationToFinish()
            presentLocationPermissionPromptIfNeeded()
        }
    }

    @MainActor
    private func waitForLaunchPresentationToFinish() async {
        for _ in 0..<40 {
            if !PaywallPresenter.shared.isPresented {
                break
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
        try? await Task.sleep(for: .milliseconds(400))
    }

    private func presentLocationPermissionPromptIfNeeded() {
        guard isTabActive else { return }
        guard !PaywallPresenter.shared.isPresented else { return }
        guard !LocationWeatherPermissionPromptStore.userDismissedPrompt else { return }

        switch environment.permissionPromptAction() {
        case .none:
            break
        case .requestSystemAuthorization:
            environment.requestSystemLocationAuthorization()
        case .showSettingsPrompt:
            showLocationWeatherPermissionDenied = true
        }
    }

    private func handleEnvironmentPermissionIfNeeded() {
        presentLocationPermissionPromptIfNeeded()
    }

    private func refreshFullscreenLEDGuideVisibility() {
        guard isTabActive, !FullscreenLEDGuideStore.hasSeenGuide else {
            showsFullscreenLEDGuide = false
            return
        }
        showsFullscreenLEDGuide = true
    }

    private func dismissFullscreenLEDGuide(method: String? = nil) {
        guard showsFullscreenLEDGuide else { return }
        if let method {
            AppTelemetry.logProductEvent(
                "onboarding_dismissed",
                parameters: ["method": method]
            )
        }
        showsFullscreenLEDGuide = false
        FullscreenLEDGuideStore.markSeen()
    }

    private var footerNote: String {
        if measurementMode.isHighSensitivity {
            L10n.dashboardFooterHighSensitivity
        } else {
            L10n.dashboardFooterStandard
        }
    }

    private func persistMeasurementSample() {
        let signpost = PerformanceSignpost.begin(.persistMeasurement)
        defer { PerformanceSignpost.end(.persistMeasurement, signpost) }

        let now = Date()
        let sample = MeasurementSample(
            timestamp: now,
            dbCurrent: engine.currentDB,
            dbMax: engine.maxDB,
            dbMin: engine.minDB,
            dbAvg: engine.averageDB,
            leq: engine.leq,
            weighting: engine.effectiveWeighting.rawValue,
            noiseType: engine.latestNoiseLabel
        )
        modelContext.insert(sample)
        try? modelContext.save()
        measurementPersistTick += 1
        if measurementPersistTick % 12 == 0 {
            MeasurementDataStore.pruneSamplesIfNeeded(in: modelContext)
        }
    }

    private func exportCSV() {
        let descriptor = FetchDescriptor<MeasurementSample>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let samples = try? modelContext.fetch(descriptor) else { return }
        let rows = samples.map {
            MeasurementCSVRow(
                timestamp: $0.timestamp,
                dbCurrent: $0.dbCurrent,
                dbMax: $0.dbMax,
                dbMin: $0.dbMin,
                dbAvg: $0.dbAvg,
                leq: $0.leq,
                weighting: $0.weighting,
                noiseType: $0.noiseType
            )
        }
        guard let url = CSVExporter.exportMeasurementLog(rows: rows) else {
            csvExportErrorMessage = L10n.dashboardExportCSVFailed
            return
        }
        csvShareURL = url
        showCSVShare = true
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct StatCard: View {
    let title: String
    let value: Float
    var theme: ModeVisualTheme = .theme(for: .standard)

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f", value))
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ShareReportSheet: View {
    let report: SilenceRatingReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(report.summaryText)
                    .font(.body)
                    .padding()
            }
            .navigationTitle(L10n.silenceReportTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(uiImage: report.renderShareImage()), preview: SharePreview(L10n.silenceReportSharePreview, image: Image(uiImage: report.renderShareImage())))
                }
            }
        }
    }
}
