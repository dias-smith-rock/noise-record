import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var engine = NoiseMonitorEngine()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(engine: engine)
            }
            .tabItem {
                Label("监测", systemImage: "waveform")
            }

            NavigationStack {
                RecorderSettingsView(engine: engine)
            }
            .tabItem {
                Label("声控", systemImage: "record.circle")
            }

            NavigationStack {
                VideoEvidenceView(engine: engine)
            }
            .tabItem {
                Label("录像", systemImage: "video.fill")
            }

            NavigationStack {
                RecordingListView(engine: engine)
            }
            .tabItem {
                Label("文件", systemImage: "list.bullet")
            }

            NavigationStack {
                SettingsView(engine: engine)
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .onAppear {
            engine.onRecordingFinished = { event in
                saveRecording(event)
            }
        }
    }

    private func saveRecording(_ event: RecordingFinishedEvent) {
        let session = RecordingSession(
            fileName: event.fileURL.lastPathComponent,
            filePath: event.fileURL.path,
            startedAt: event.startedAt,
            endedAt: event.endedAt,
            peakDB: event.peakDB,
            averageDB: event.averageDB,
            noiseType: event.noiseType
        )
        modelContext.insert(session)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordingSession.self, MeasurementSample.self, VideoEvidenceSession.self], inMemory: true)
}
