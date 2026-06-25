import SwiftData
import SwiftUI

struct DashboardView: View {
    private static let showsReportAndCSVExport = false
    private static let measurementPersistInterval: TimeInterval = 5

    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    @Bindable private var appearance = AppAppearanceSettings.shared
    let isTabActive: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var shareReport: SilenceRatingReport?
    @State private var showReportSheet = false
    @State private var csvShareURL: URL?
    @State private var showCSVShare = false
    @State private var showStopRecordingPrompt = false
    @State private var csvExportErrorMessage: String?
    @State private var measurementPersistTick = 0
    @State private var isFullScreenPresented = false
    @State private var showsFullscreenLEDGuide = false
    @State private var fullscreenButtonFrame: CGRect = .zero
    @State private var environment = AmbientEnvironmentProvider()

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        let _ = appearance.temperatureUnitPreference

        VStack(spacing: 0) {
            ProTabHeader(title: L10n.dashboardTitle, theme: theme)

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
        }
        .onChange(of: isTabActive) { _, _ in
            refreshFullscreenLEDGuideVisibility()
        }
        .onDisappear {
            environment.stopUpdating()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProFloatingActionButton(
                title: monitorActionTitle,
                systemImage: monitorActionSymbol,
                theme: theme,
                isDestructive: audioStateManager.appAudioState == .monitoring
            ) {
                guard audioStateManager.appAudioState != .playing else { return }
                AdSceneLifecycle.recordFirstInteraction(source: "monitor_toggle")
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
            guard engine.isMonitoring else { return }
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
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { csvExportErrorMessage != nil },
            set: { if !$0 { csvExportErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { csvExportErrorMessage = nil }
        } message: {
            Text(csvExportErrorMessage ?? "")
        }
        .alert(L10n.dashboardStopPromptTitle, isPresented: $showStopRecordingPrompt) {
            Button(L10n.dashboardStopPromptSave) {
                commitStopSaveDecision(keep: true)
            }
            Button(L10n.dashboardStopPromptDiscard, role: .destructive) {
                commitStopSaveDecision(keep: false)
            }
        } message: {
            Text(stopRecordingPromptMessage)
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
                AppTelemetry.logProductEvent(
                    "fullscreen_led_open",
                    parameters: ["mode": measurementMode.rawValue]
                )
                InterfaceOrientationLocker.enterLandscapeFullscreen()
                AdSceneLifecycle.showInterstitialOnFullscreenEnter()
            } else {
                AppTelemetry.logProductEvent("fullscreen_led_close")
                InterfaceOrientationLocker.exitLandscapeFullscreen()
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

            if engine.voiceActivatedEnabled {
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
                WaveformView(samples: engine.history, mode: measurementMode)
                    .equatable()
                    .frame(height: 120)
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

    private var monitorActionTitle: String {
        switch audioStateManager.appAudioState {
        case .monitoring: L10n.dashboardStop
        case .idle: L10n.dashboardStart
        case .playing: L10n.dashboardPlayingPlaceholder
        }
    }

    private var monitorActionSymbol: String {
        switch audioStateManager.appAudioState {
        case .monitoring: "stop.circle.fill"
        case .idle: "play.circle.fill"
        case .playing: "speaker.wave.2.fill"
        }
    }

    private var stopRecordingPromptMessage: String {
        let total = engine.currentSessionRecordingCount + engine.deferredRecordingsForStopPrompt.count
        if total > 1 {
            return L10n.dashboardStopPromptMultiple(total)
        }
        return L10n.dashboardStopPromptInProgress
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

    /// 停止监测：与 `voiceActivatedEnabled` 当前开关无关；有录音 / 曾录制 / deferred 非空即询问是否保留。
    private func handleStopMonitoringTapped() {
        let hadSavedRecordings = !engine.currentSessionRecordingIDs.isEmpty
        let wasCapturing = engine.activeVoiceCaptureState != .idle
        if hadSavedRecordings || wasCapturing {
            engine.prepareStopWithSavePrompt()
        }

        audioStateManager.stopMonitoringManually()

        let needsSavePrompt = hadSavedRecordings
            || wasCapturing
            || !engine.deferredRecordingsForStopPrompt.isEmpty
            || !engine.currentSessionRecordingIDs.isEmpty

        if needsSavePrompt {
            Task { @MainActor in
                await Task.yield()
                showStopRecordingPrompt = true
            }
        } else {
            engine.clearMonitoringSessionTracking()
        }
    }

    private func commitStopSaveDecision(keep: Bool) {
        if keep {
            engine.commitDeferredRecordings()
        } else {
            engine.isDiscardingSessionRecordings = true
            engine.discardDeferredRecordings()
            deleteCurrentSessionRecordings()
            engine.isDiscardingSessionRecordings = false
        }
        engine.clearMonitoringSessionTracking()
    }

    private func deleteCurrentSessionRecordings() {
        let ids = engine.currentSessionRecordingIDs
        guard !ids.isEmpty else { return }

        for id in ids {
            var descriptor = FetchDescriptor<RecordingSession>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            guard let session = try? modelContext.fetch(descriptor).first else { continue }
            try? FileManager.default.removeItem(at: session.fileURL)
            modelContext.delete(session)
        }
        try? modelContext.save()
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
