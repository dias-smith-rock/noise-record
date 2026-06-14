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

    @State private var engine = NoiseMonitorEngine()
    @State private var selectedTab: MainTab = .monitor
    @State private var mountedTabs: Set<MainTab> = [.monitor]
    @State private var hasUnreadFiles = false
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let _ = appearance.languageRefreshID
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
            mountedTabs.insert(tab)
            if tab == .files {
                refreshUnreadBadge()
            }
        }
        .onChange(of: appearance.languageRefreshID) { _, _ in
            TabBarAppearanceUpdater.applyTabTitles()
            refreshMonitorTabIconIfNeeded()
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                AppTelemetry.log("scene_inactive")
                engine.prepareForBackgroundIfNeeded()
            case .background:
                AppTelemetry.logEvent("scene_background")
                engine.handleDidEnterBackground()
            case .active:
                AppTelemetry.logEvent("scene_active")
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
            DashboardView(engine: engine, isTabActive: selectedTab == .monitor)
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
            VideoEvidenceView(engine: engine, isTabActive: selectedTab == .video)
        }
        .tag(MainTab.video)
        .tabItem {
            Label(L10n.tabVideo, systemImage: "video.fill")
        }
    }

    @ViewBuilder
    private var filesTab: some View {
        tabRoot(for: .files) {
            RecordingListView(engine: engine, isTabActive: selectedTab == .files)
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

    private func saveRecording(_ event: RecordingFinishedEvent) {
        if engine.isDiscardingSessionRecordings {
            try? FileManager.default.removeItem(at: event.fileURL)
            return
        }

        let session = RecordingSession(
            fileName: event.fileURL.lastPathComponent,
            filePath: EvidenceFileResolver.makeRelativePath(from: event.fileURL),
            startedAt: event.startedAt,
            endedAt: event.endedAt,
            peakDB: event.peakDB,
            averageDB: event.averageDB,
            noiseType: event.noiseType
        )
        modelContext.insert(session)
        engine.noteRecordingSaved(id: session.id)
        try? modelContext.save()
        refreshUnreadBadge()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordingSession.self, MeasurementSample.self, VideoEvidenceSession.self], inMemory: true)
}
