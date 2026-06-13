import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var engine = NoiseMonitorEngine()
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(engine: engine)
            }
            .tabItem {
                Label(L10n.tabMonitor, systemImage: "waveform")
            }

            NavigationStack {
                RecorderSettingsView(engine: engine)
            }
            .tabItem {
                Label(L10n.tabVoice, systemImage: "record.circle")
            }

            NavigationStack {
                VideoEvidenceView(engine: engine)
            }
            .tabItem {
                Label(L10n.tabVideo, systemImage: "video.fill")
            }

            NavigationStack {
                RecordingListView(engine: engine)
            }
            .tabItem {
                Label(L10n.tabFiles, systemImage: "list.bullet")
            }

            NavigationStack {
                SettingsView(engine: engine)
            }
            .tabItem {
                Label(L10n.tabSettings, systemImage: "gearshape")
            }
        }
        .preferredColorScheme(appearance.colorSchemePreference.colorScheme)
        .environment(\.locale, AppLocalization.resolvedLocale)
        .id(appearance.languageRefreshID)
        .onAppear {
            engine.onRecordingFinished = { event in
                saveRecording(event)
            }
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordingSession.self, MeasurementSample.self, VideoEvidenceSession.self], inMemory: true)
}
