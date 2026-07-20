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
    @State private var sleepCoordinator = SleepNoiseMonitorCoordinator()
    @State private var videoCoordinator = VideoEvidenceCoordinator()
    @State private var selectedTab: MainTab = .monitor
    @State private var mountedTabs: Set<MainTab> = [.monitor]
    @State private var showAppReviewPrompt = false
    @State private var showMicPermissionIntro = false
    @State private var suppressNextTabSelectionAd = false
    @State private var pendingEvidenceRecordingID: UUID?
    @Query(filter: #Predicate<RecordingSession> { $0.isNew == true })
    private var unreadAudioSessions: [RecordingSession]
    @Query(filter: #Predicate<VideoEvidenceSession> { $0.isNew == true })
    private var unreadVideoSessions: [VideoEvidenceSession]
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Bindable private var paywallPresenter = PaywallPresenter.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private var hasUnreadFiles: Bool {
        !unreadAudioSessions.isEmpty || !unreadVideoSessions.isEmpty
    }

    private var unreadFilesCount: Int {
        unreadAudioSessions.count + unreadVideoSessions.count
    }

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
            LaunchPerformance.mark(.launchFirstInteractive)
            MonitoringFunnelTracker.resetProcessLaunchClock()
            sleepCoordinator.configure(engine: engine, modelContext: modelContext)
            syncAppReviewFilesCount()
            engine.onRecordingFinished = { event in
                saveRecording(event)
            }
            engine.onVideoEmergencyFinalize = { [videoCoordinator] in
                videoCoordinator.emergencyFinalizeIfRecording()
            }
            VideoEvidenceRecovery.removeStalePartFiles()
            _ = VideoEvidenceRecovery.recoverOrphanedFiles(modelContext: modelContext)
            syncAppReviewFilesCount()
            if let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController {
                TabBarAppearanceUpdater.cacheTabBarController(from: root)
            }
            TabBarAppearanceUpdater.applyTabTitles()
            Task { await SleepNotificationScheduler.scheduleDailyReminders() }
            handlePendingSleepNotificationAction()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: SleepNotificationRouter.actionPendingNotification
            )
        ) { _ in
            handlePendingSleepNotificationAction()
        }
        .onChange(of: unreadFilesCount) { _, _ in
            syncAppReviewFilesCount()
        }
        .onChange(of: selectedTab) { _, tab in
            AppTelemetry.logProductEvent(
                "tab_selected",
                parameters: ["tab": analyticsTabName(for: tab)]
            )
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
                syncAppReviewFilesCount()
                AppOnboardingStore.noteFilesTabVisited()
            }
        }
        .onChange(of: appearance.languageRefreshID) { _, _ in
            TabBarAppearanceUpdater.applyTabTitles()
            refreshMonitorTabIconIfNeeded()
        }
        .onOpenURL { url in
            guard url.scheme == LiveActivityDeepLink.scheme else { return }
            if url.host == LiveActivityDeepLink.evidenceHost,
               let recordingID = UUID(uuidString: url.lastPathComponent) {
                AppTelemetry.logProductEvent(
                    "deeplink_opened",
                    parameters: ["target": "evidence"]
                )
                pendingEvidenceRecordingID = recordingID
                suppressNextTabSelectionAd = true
                mountedTabs.insert(.files)
                selectedTab = .files
                return
            }
            if url.host == LiveActivityDeepLink.sleepReportHost,
               let sessionID = UUID(uuidString: url.lastPathComponent) {
                AppTelemetry.logProductEvent(
                    "deeplink_opened",
                    parameters: ["target": "sleep_report"]
                )
                sleepCoordinator.presentReport(sessionID: sessionID, source: "deeplink")
                suppressNextTabSelectionAd = true
                selectedTab = .monitor
                return
            }
            guard url.host == LiveActivityDeepLink.monitorHost else { return }
            AppTelemetry.logProductEvent(
                "deeplink_opened",
                parameters: ["target": "monitor"]
            )
            suppressNextTabSelectionAd = true
            selectedTab = .monitor
        }
        .sheet(isPresented: Binding(
            get: { sleepCoordinator.showReportSheet },
            set: { if !$0 { sleepCoordinator.dismissReportSheet() } }
        )) {
            if let sessionID = sleepCoordinator.latestReportSessionID {
                SleepReportView(
                    sessionID: sessionID,
                    themeMeasurementMode: AcousticMeasurementMode(
                        isHighSensitivity: engine.isHighSensitivityMode
                    )
                ) {
                    sleepCoordinator.markReportRead(for: sessionID)
                    sleepCoordinator.dismissReportSheet()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { sleepCoordinator.showHistorySheet },
            set: { if !$0 { sleepCoordinator.dismissHistorySheet() } }
        )) {
            sleepHistorySheet
        }
        .task(id: engine.isMonitoring) {
            guard engine.isMonitoring else {
                TabBarMonitorIconUpdater.apply(frame: nil, isAnimating: false)
                return
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    while !Task.isCancelled {
                        await MainActor.run {
                            TabBarMonitorIconUpdater.apply(
                                frame: MonitorTabBarWaveformRenderer.render(
                                    at: Date().timeIntervalSinceReferenceDate
                                ),
                                isAnimating: true
                            )
                        }
                        try? await Task.sleep(for: .milliseconds(66))
                    }
                }
                group.addTask {
                    let interval: TimeInterval = 5
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(interval))
                        AppReviewStore.recordMonitoringElapsed(interval)
                        await MainActor.run {
                            evaluateAppReviewPromptIfNeeded()
                        }
                    }
                }
            }

            TabBarMonitorIconUpdater.apply(frame: nil, isAnimating: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppReviewStore.shouldPresentPromptNotification)) { _ in
            showAppReviewPrompt = true
        }
        .onReceive(NotificationCenter.default.publisher(for: AppReviewStore.shouldReevaluatePromptNotification)) { _ in
            evaluateAppReviewPromptIfNeeded()
        }
        .onChange(of: showAppReviewPrompt) { _, isPresented in
            if isPresented {
                AppReviewStore.markReviewPromptPresented()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchAutoStartMonitoring)) { _ in
            Task {
                await handleLaunchAutoStartMonitoring()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingMeasureReportDue)) { _ in
            engine.exportOnboardingMonitoringSnapshot()
            syncAppReviewFilesCount()
        }
        .sheet(isPresented: $showMicPermissionIntro) {
            MicPermissionIntroSheet(
                theme: ModeVisualTheme.theme(
                    for: AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
                ),
                onContinue: {
                    MicPermissionIntroStore.markSeen()
                    showMicPermissionIntro = false
                    Task { await performLaunchAutoStartMonitoring() }
                },
                onDismiss: {
                    MicPermissionIntroStore.markSeen()
                    showMicPermissionIntro = false
                }
            )
        }
        .onChange(of: engine.currentDB) { _, currentDB in
            MonitoringFunnelTracker.observeReading(
                currentDB: currentDB,
                isMonitoring: engine.isMonitoring
            )
        }
        .onChange(of: engine.isMonitoring) { wasMonitoring, isMonitoring in
            if isMonitoring {
                audioStateManager.noteMonitoringStarted()
                if !wasMonitoring {
                    MonitoringFunnelTracker.noteMonitoringStarted()
                }
            } else if wasMonitoring {
                audioStateManager.noteMonitoringStopped()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fullscreenAdDidDismiss)) { _ in
            audioStateManager.recoverAfterFullscreenAdDismiss()
        }
        .appReviewPrompt(isPresented: $showAppReviewPrompt)
        .onChange(of: engine.sessionStopPromptID) { _, promptID in
            if promptID == nil {
                evaluateAppReviewPromptIfNeeded()
            }
        }
        .onChange(of: sleepCoordinator.showReportSheet) { _, isPresented in
            if isPresented {
                showAppReviewPrompt = false
                AppReviewStore.cancelPendingReviewPrompt()
            } else {
                evaluateAppReviewPromptIfNeeded()
            }
        }
        .onChange(of: paywallPresenter.isPresented) { _, isPresented in
            if !isPresented {
                evaluateAppReviewPromptIfNeeded()
            }
        }
        .onChange(of: engine.sessionAutoSaveGateID) { _, gateID in
            guard gateID != nil else { return }
            applyDeferredSessionSaveGate()
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
                handlePendingSleepNotificationAction()
                guard audioStateManager.allowsAutomaticMonitoringRecovery else { return }
                engine.handleDidBecomeActive()
                sleepCoordinator.presentPendingReportIfNeeded()
                syncAppReviewFilesCount()
                evaluateAppReviewPromptIfNeeded()
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
                sleepCoordinator: sleepCoordinator,
                isTabActive: selectedTab == .monitor,
                onOpenVideoEvidence: {
                    AdSceneLifecycle.recordFirstInteraction(source: "dashboard_video_evidence")
                    selectedTab = .video
                }
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
        let tab = tabRoot(for: .files) {
            RecordingListView(
                engine: engine,
                audioStateManager: audioStateManager,
                sleepCoordinator: sleepCoordinator,
                environmentSnapshot: {
                    SleepEnvironmentSnapshot(
                        latitude: engine.evidenceLatitude,
                        longitude: engine.evidenceLongitude
                    )
                },
                isTabActive: selectedTab == .files,
                pendingOpenRecordingID: $pendingEvidenceRecordingID
            )
        }
        .tag(MainTab.files)
        .tabItem {
            Label(L10n.tabFiles, systemImage: "list.bullet")
        }

        if hasUnreadFiles {
            tab.badge(unreadFilesCount)
        } else {
            tab
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

    private func syncAppReviewFilesCount() {
        AppReviewStore.updateLatestFilesCount(totalSavedFilesCount())
    }

    private func totalSavedFilesCount() -> Int {
        let audioTotal = (try? modelContext.fetchCount(FetchDescriptor<RecordingSession>())) ?? 0
        let videoTotal = (try? modelContext.fetchCount(FetchDescriptor<VideoEvidenceSession>())) ?? 0
        return audioTotal + videoTotal
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
            syncAppReviewFilesCount()
        case .requiresPaywall:
            AppTelemetry.logProductEvent(
                "freemium_limit_hit",
                parameters: ["limit_type": "voice_duration"]
            )
            PaywallPresenter.shared.present(context: .voiceDurationLimit) { purchased in
                if purchased {
                    engine.commitDeferredSessionRecording()
                    syncAppReviewFilesCount()
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
        let sleepSessionID = sleepCoordinator.sleepSessionIDForRecording(
            isSleepAnomalyClip: event.isSleepAnomalyClip
        )
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
            isSessionRecording: event.isSessionRecording,
            sleepSessionID: sleepSessionID
        )
        modelContext.insert(session)
        try? modelContext.save()
        sleepCoordinator.noteRecordingSaved(session)
        syncAppReviewFilesCount()
        if totalSavedFilesCount() >= AppReviewStore.minimumFilesForReviewPrompt {
            AppReviewStore.noteCoreFeatureUsed(.evidenceSaved)
        }
        evaluateAppReviewPromptIfNeeded()
    }

    private func evaluateAppReviewPromptIfNeeded() {
        AppReviewStore.evaluatePromptIfEligible(isBusy: isAppReviewPromptBusy)
    }

    private var sleepHistorySheet: some View {
        let mode = AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
        let theme = ModeVisualTheme.theme(for: mode)
        return NavigationStack {
            SleepHistoryView(measurementMode: mode)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.close) {
                            sleepCoordinator.dismissHistorySheet()
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
        }
        .tint(theme.accent)
    }

    private var isAppReviewPromptBusy: Bool {
        engine.sessionStopPromptID != nil
            || PaywallPresenter.shared.isPresented
            || videoCoordinator.isRecording
            || AppReviewStore.isFullscreenLEDBusy
            || sleepCoordinator.isSleepReportFlowActive
            || sleepCoordinator.showReportSheet
    }

    private func analyticsTabName(for tab: MainTab) -> String {
        switch tab {
        case .monitor: "monitor"
        case .voice: "voice"
        case .video: "video"
        case .files: "files"
        case .settings: "settings"
        }
    }

    private func handleLaunchAutoStartMonitoring() async {
        guard MonitorSettingsStore.autoStartMonitoringOnLaunch else { return }
        guard audioStateManager.appAudioState != .playing else { return }

        if shouldPresentMicPermissionIntro {
            showMicPermissionIntro = true
            return
        }

        await performLaunchAutoStartMonitoring()
    }

    private var shouldPresentMicPermissionIntro: Bool {
        AudioSessionManager.isMicrophonePermissionUndetermined
            && !MicPermissionIntroStore.hasSeenIntro
    }

    private func performLaunchAutoStartMonitoring() async {
        await audioStateManager.manuallyResumeMonitoring()
        if engine.isMonitoring {
            AppTelemetry.logProductEvent("monitoring_auto_start_launch")
        }
    }

    private func handlePendingSleepNotificationAction() {
        guard let action = SleepNotificationRouter.consumePendingAction() else { return }

        suppressNextTabSelectionAd = true
        mountedTabs.insert(.monitor)
        selectedTab = .monitor

        switch action {
        case .openTodayReport:
            _ = sleepCoordinator.presentTodayReportIfAvailable(source: "notification")
        case .openReport(let sessionID):
            sleepCoordinator.presentReport(sessionID: sessionID, source: "notification")
        case .startSleepMonitoring:
            Task {
                await startSleepMonitoringFromNotification()
            }
        }
    }

    private func startSleepMonitoringFromNotification() async {
        let started = await sleepCoordinator.startSession(
            isHighSensitivity: engine.isHighSensitivityMode
        )
        guard started else { return }
        audioStateManager.noteMonitoringStarted()
        NotificationCenter.default.post(
            name: SleepNotificationRouter.sleepMonitoringStartedFromNotification,
            object: nil
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            RecordingSession.self,
            MeasurementSample.self,
            VideoEvidenceSession.self,
            SleepNoiseSession.self,
            SleepAnomalyEvent.self,
        ], inMemory: true)
}
