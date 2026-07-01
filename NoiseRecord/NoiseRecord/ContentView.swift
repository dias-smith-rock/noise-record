import SwiftData
import SwiftUI

struct ContentView: View {
    private enum MainTab: Hashable {
        case monitor
        case voice
        case video
        case files
        case settings
    }

    @State private var engine: NoiseMonitorEngine
    @State private var audioStateManager: AudioStateManager
    @State private var videoCoordinator = VideoEvidenceCoordinator()
    @State private var selectedTab: MainTab = .monitor
    @State private var mountedTabs: Set<MainTab> = [.monitor]
    @State private var hasUnreadFiles = false
    @State private var showAppReviewPrompt = false
    @State private var showSessionStopPrompt = false
    @State private var suppressNextTabSelectionAd = false
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let engine = NoiseMonitorEngine()
        _engine = State(wrappedValue: engine)
        _audioStateManager = State(wrappedValue: AudioStateManager(engine: engine))
    }

    var body: some View {
        let _ = appearance.languageRefreshID
        let _ = appearance.accentRefreshID
        let locale = AppLocalization.resolvedLocale(for: appearance.preferredLanguage)

        TabView(selection: $selectedTab) {
            monitorTab
            voiceTab
            videoTab
            filesTab
            settingsTab
        }
        .environment(\.locale, locale)
        .environment(\.appLanguageRevision, appearance.languageRefreshID)
        .preferredColorScheme(appearance.colorSchemePreference.colorScheme)
        .onAppear {
            LaunchPerformance.mark(.launchContentViewAppear)
            refreshUnreadBadge()
            engine.onRecordingFinished = { event in
                saveRecording(event)
            }
            engine.onVideoEmergencyFinalize = { [videoCoordinator] in
                videoCoordinator.emergencyFinalizeIfRecording()
            }
            VideoEvidenceRecovery.removeStalePartFiles()
            _ = VideoEvidenceRecovery.recoverOrphanedFiles(modelContext: modelContext)
            refreshUnreadBadge()
            if let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController {
                TabBarAppearanceUpdater.cacheTabBarController(from: root)
            }
            TabBarAppearanceUpdater.applyTabTitles()
        }
        .onChange(of: selectedTab) { _, tab in
            if suppressNextTabSelectionAd {
                suppressNextTabSelectionAd = false
            } else {
                AdSceneLifecycle.recordFirstInteraction(source: "tab_switch")
            }
            if tab == .video {
                VideoTabPerformance.beginSession()
                VideoTabPerformance.mark(.tabSelected)
            }
            mountedTabs.insert(tab)
            if tab == .files {
                refreshUnreadBadge()
            }
        }
        .onChange(of: appearance.languageRefreshID) { _, _ in
            TabBarAppearanceUpdater.applyTabTitles()
            refreshMonitorTabIconIfNeeded()
        }
        .onOpenURL { url in
            guard url.scheme == LiveActivityDeepLink.scheme,
                  url.host == LiveActivityDeepLink.monitorHost else { return }
            suppressNextTabSelectionAd = true
            selectedTab = .monitor
        }
        .task(id: engine.isMonitoring) {
            guard engine.isMonitoring else {
                TabBarMonitorIconUpdater.apply(frame: nil, isAnimating: false)
                return
            }

            while !Task.isCancelled, engine.isMonitoring {
                TabBarMonitorIconUpdater.apply(
                    frame: MonitorTabBarWaveformRenderer.render(
                        at: Date().timeIntervalSinceReferenceDate
                    ),
                    isAnimating: true
                )
                try? await Task.sleep(for: .milliseconds(66))
            }

            TabBarMonitorIconUpdater.apply(frame: nil, isAnimating: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppReviewStore.shouldPresentPromptNotification)) { _ in
            showAppReviewPrompt = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchAutoStartMonitoring)) { _ in
            Task {
                guard MonitorSettingsStore.autoStartMonitoringOnLaunch else { return }
                guard audioStateManager.appAudioState != .playing else { return }
                await audioStateManager.manuallyResumeMonitoring()
                if engine.isMonitoring {
                    AppTelemetry.logProductEvent("monitoring_auto_start_launch")
                }
            }
        }
        .appReviewPrompt(isPresented: $showAppReviewPrompt)
        .onChange(of: engine.sessionStopPromptID) { _, promptID in
            showSessionStopPrompt = promptID != nil
        }
        .onChange(of: engine.sessionAutoSaveGateID) { _, gateID in
            guard gateID != nil else { return }
            applyDeferredSessionSaveGate()
        }
        .alert(L10n.dashboardStopPromptSessionTitle, isPresented: $showSessionStopPrompt) {
            Button(L10n.dashboardStopPromptSave) {
                handleDeferredSessionSave()
            }
            Button(L10n.dashboardStopPromptDiscard, role: .destructive) {
                engine.discardDeferredSessionRecording()
            }
        } message: {
            if let summary = engine.pendingSessionStopSummary {
                Text(
                    L10n.dashboardStopPromptSessionMessage(
                        duration: DurationFormatting.hms(from: summary.duration),
                        fileSize: DurationFormatting.fileSize(from: summary.fileSizeBytes),
                        segmentCount: summary.autoSavedSegmentCount
                    )
                )
            }
        }
        .onChange(of: engine.isMonitoring) { _, isMonitoring in
            if isMonitoring {
                audioStateManager.noteMonitoringStarted()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                AppTelemetry.log("scene_inactive")
                guard audioStateManager.allowsAutomaticMonitoringRecovery else { return }
                engine.prepareForBackgroundIfNeeded()
            case .background:
                AppTelemetry.log("scene_background")
                guard audioStateManager.allowsAutomaticMonitoringRecovery else { return }
                engine.handleDidEnterBackground()
            case .active:
                AppTelemetry.log("scene_active")
                guard audioStateManager.allowsAutomaticMonitoringRecovery else { return }
                engine.handleDidBecomeActive()
                refreshUnreadBadge()
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var monitorTab: some View {
        tabRoot(for: .monitor) {
            DashboardView(
                engine: engine,
                audioStateManager: audioStateManager,
                isTabActive: selectedTab == .monitor
            )
        }
        .tag(MainTab.monitor)
        .tabItem {
            Label(L10n.tabMonitor, systemImage: "waveform")
        }
    }

    @ViewBuilder
    private var voiceTab: some View {
        tabRoot(for: .voice) {
            RecorderSettingsView(engine: engine, isTabActive: selectedTab == .voice)
        }
        .tag(MainTab.voice)
        .tabItem {
            Label(L10n.tabVoice, systemImage: "record.circle")
        }
    }

    @ViewBuilder
    private var videoTab: some View {
        tabRoot(for: .video) {
            VideoEvidenceView(
                engine: engine,
                audioStateManager: audioStateManager,
                coordinator: videoCoordinator,
                isTabActive: selectedTab == .video
            )
        }
        .tag(MainTab.video)
        .tabItem {
            Label(L10n.tabVideo, systemImage: "video.fill")
        }
    }

    @ViewBuilder
    private var filesTab: some View {
        tabRoot(for: .files) {
            RecordingListView(
                engine: engine,
                audioStateManager: audioStateManager,
                isTabActive: selectedTab == .files
            )
        }
        .badge(hasUnreadFiles ? "" : nil)
        .tag(MainTab.files)
        .tabItem {
            Label(L10n.tabFiles, systemImage: "list.bullet")
        }
    }

    @ViewBuilder
    private var settingsTab: some View {
        tabRoot(for: .settings) {
            SettingsView(engine: engine, isTabActive: selectedTab == .settings)
        }
        .tag(MainTab.settings)
        .tabItem {
            Label(L10n.tabSettings, systemImage: "gearshape")
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(for tab: MainTab, @ViewBuilder content: () -> Content) -> some View {
        if mountedTabs.contains(tab) {
            NavigationStack {
                content()
            }
        } else {
            Color.clear
        }
    }

    private func refreshUnreadBadge() {
        let audioDescriptor = FetchDescriptor<RecordingSession>(
            predicate: #Predicate { $0.isNew == true }
        )
        let videoDescriptor = FetchDescriptor<VideoEvidenceSession>(
            predicate: #Predicate { $0.isNew == true }
        )
        let audioCount = (try? modelContext.fetchCount(audioDescriptor)) ?? 0
        let videoCount = (try? modelContext.fetchCount(videoDescriptor)) ?? 0
        hasUnreadFiles = audioCount > 0 || videoCount > 0
    }

    private func refreshMonitorTabIconIfNeeded() {
        guard engine.isMonitoring else { return }
        TabBarMonitorIconUpdater.apply(
            frame: MonitorTabBarWaveformRenderer.render(
                at: Date().timeIntervalSinceReferenceDate
            ),
            isAnimating: true
        )
    }

    private func handleDeferredSessionSave() {
        applyDeferredSessionSaveGate()
    }

    private func applyDeferredSessionSaveGate() {
        switch engine.deferredSessionSaveGate() {
        case .saveImmediately:
            engine.commitDeferredSessionRecording()
            refreshUnreadBadge()
        case .requiresPaywall:
            AppTelemetry.logProductEvent(
                "freemium_limit_hit",
                parameters: ["limit_type": "voice_duration"]
            )
            PaywallPresenter.shared.present(context: .voiceDurationLimit) { purchased in
                if purchased {
                    engine.commitDeferredSessionRecording()
                    refreshUnreadBadge()
                } else {
                    engine.discardDeferredSessionRecording()
                }
            }
        case .nothingToSave:
            engine.clearStopSavePromptState()
        }
    }

    private func saveRecording(_ event: RecordingFinishedEvent) {
        let fileName = event.fileURL.lastPathComponent
        let startedAt = RecordingSession.parseStartDate(from: fileName) ?? event.startedAt
        let session = RecordingSession(
            fileName: fileName,
            filePath: EvidenceFileResolver.makeRelativePath(from: event.fileURL),
            startedAt: startedAt,
            endedAt: event.endedAt,
            peakDB: event.peakDB,
            averageDB: event.averageDB,
            noiseType: event.noiseType,
            latitude: event.latitude,
            longitude: event.longitude,
            segmentGroupID: event.segmentGroupID,
            segmentIndex: event.segmentIndex,
            isSessionRecording: event.isSessionRecording
        )
        modelContext.insert(session)
        try? modelContext.save()
        refreshUnreadBadge()
        AppReviewStore.noteEvidenceFileSaved()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordingSession.self, MeasurementSample.self, VideoEvidenceSession.self], inMemory: true)
}
