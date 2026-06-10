import SwiftData
import SwiftUI

@main
struct NoiseRecordApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecordingSession.self,
            MeasurementSample.self,
            VideoEvidenceSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
