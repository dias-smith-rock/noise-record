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
    @State private var showsFilesTabBadge = FilesTabBadgeStore.isPending
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(engine: engine, isTabActive: selectedTab == .monitor)
            }
            .id(appearance.languageRefreshID)
            .tag(MainTab.monitor)
            .tabItem {
                Label(L10n.tabMonitor, systemImage: "waveform")
            }

            NavigationStack {
                RecorderSettingsView(engine: engine, isTabActive: selectedTab == .voice)
            }
            .id(appearance.languageRefreshID)
            .tag(MainTab.voice)
            .tabItem {
                Label(L10n.tabVoice, systemImage: "record.circle")
            }

            NavigationStack {
                VideoEvidenceView(engine: engine, isTabActive: selectedTab == .video)
            }
            .id(appearance.languageRefreshID)
            .tag(MainTab.video)
            .tabItem {
                Label(L10n.tabVideo, systemImage: "video.fill")
            }

            NavigationStack {
                RecordingListView(engine: engine, isTabActive: selectedTab == .files)
            }
            .id(appearance.languageRefreshID)
            .tag(MainTab.files)
            .tabItem {
                Label(L10n.tabFiles, systemImage: "list.bullet")
            }
            NavigationStack {
                SettingsView(engine: engine, isTabActive: selectedTab == .settings)
            }
            .id(appearance.languageRefreshID)
            .tag(MainTab.settings)
            .tabItem {
                Label(L10n.tabSettings, systemImage: "gearshape")
            }
        }
        .preferredColorScheme(appearance.colorSchemePreference.colorScheme)
        .onAppear {
            engine.onRecordingFinished = { event in
                saveRecording(event)
            }
            showsFilesTabBadge = FilesTabBadgeStore.isPending
            if let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController {
                TabBarAppearanceUpdater.cacheTabBarController(from: root)
                TabBarMonitorIconUpdater.cacheTabBarController(from: root)
            }
            TabBarAppearanceUpdater.applyTabTitles()
            TabBarAppearanceUpdater.setFilesBadgeVisible(showsFilesTabBadge)
        }
        .onReceive(NotificationCenter.default.publisher(for: FilesTabBadgeStore.didChangeNotification)) { _ in
            showsFilesTabBadge = FilesTabBadgeStore.isPending
            TabBarAppearanceUpdater.setFilesBadgeVisible(showsFilesTabBadge)
        }
        .onChange(of: appearance.languageRefreshID) { _, _ in
            TabBarAppearanceUpdater.applyTabTitles()
            TabBarAppearanceUpdater.setFilesBadgeVisible(showsFilesTabBadge)
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .files {
                FilesTabBadgeStore.clear()
                showsFilesTabBadge = false
                TabBarAppearanceUpdater.setFilesBadgeVisible(false)
            }
        }
        .onChange(of: showsFilesTabBadge) { _, isVisible in
            TabBarAppearanceUpdater.setFilesBadgeVisible(isVisible)
        }
        .task(id: engine.isVoiceRecordingRunning) {
            guard engine.isVoiceRecordingRunning else {
                TabBarMonitorIconUpdater.apply(frame: nil, isAnimating: false)
                return
            }

            while !Task.isCancelled, engine.isVoiceRecordingRunning {
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
            @unknown default:
                break
            }
        }
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
        if selectedTab != .files {
            FilesTabBadgeStore.markPending()
            showsFilesTabBadge = true
            TabBarAppearanceUpdater.setFilesBadgeVisible(true)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordingSession.self, MeasurementSample.self, VideoEvidenceSession.self], inMemory: true)
}
