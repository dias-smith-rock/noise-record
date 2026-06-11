import SwiftData
import SwiftUI

@main
struct NoiseRecordApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var storageError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    ContentView()
                        .modelContainer(modelContainer)
                } else if let storageError {
                    StorageInitErrorView(error: storageError) {
                        initializeStorage()
                    }
                } else {
                    ProgressView()
                }
            }
            .onAppear {
                if modelContainer == nil, storageError == nil {
                    initializeStorage()
                }
            }
        }
    }

    private func initializeStorage() {
        storageError = nil
        let schema = Schema([
            RecordingSession.self,
            MeasurementSample.self,
            VideoEvidenceSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            storageError = error
            modelContainer = nil
        }
    }
}
