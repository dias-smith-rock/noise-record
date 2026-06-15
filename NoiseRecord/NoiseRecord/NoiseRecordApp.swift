import SwiftData
import SwiftUI

@main
struct NoiseRecordApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var firebaseAppDelegate
    @Bindable private var appearance = AppAppearanceSettings.shared
    @State private var modelContainer: ModelContainer?
    @State private var storageError: Error?

    init() {
        AppTelemetry.configure()
        LaunchPerformance.mark(.launchAppInit)
        LaunchPerformance.mark(.launchFirebaseConfigure)
        _ = IAPManager.shared

        let signpostID = PerformanceSignpost.begin(.launchSwiftDataInit)
        defer { PerformanceSignpost.end(.launchSwiftDataInit, signpostID) }

        switch Self.makeModelContainer() {
        case .success(let container):
            _modelContainer = State(initialValue: container)
            _storageError = State(initialValue: nil)
            LaunchPerformance.mark(.launchSwiftDataInit)
            AppTelemetry.log("storage_initialized")
        case .failure(let error):
            _modelContainer = State(initialValue: nil)
            _storageError = State(initialValue: error)
            AppTelemetry.recordError(error, context: "storage_init")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    ContentView()
                        .modelContainer(modelContainer)
                        .environment(\.locale, AppLocalization.resolvedLocale(for: appearance.preferredLanguage))
                } else if let storageError {
                    StorageInitErrorView(error: storageError) {
                        retryStorage()
                    }
                }
            }
            .adSceneLifecycle()
            .onAppear {
                LaunchPerformance.mark(.launchWindowAppear)
            }
        }
    }

    private func retryStorage() {
        let signpostID = PerformanceSignpost.begin(.launchSwiftDataInit)
        defer { PerformanceSignpost.end(.launchSwiftDataInit, signpostID) }

        switch Self.makeModelContainer() {
        case .success(let container):
            modelContainer = container
            storageError = nil
            LaunchPerformance.mark(.launchSwiftDataInit)
            AppTelemetry.log("storage_initialized")
        case .failure(let error):
            storageError = error
            modelContainer = nil
            AppTelemetry.recordError(error, context: "storage_init")
        }
    }

    private static func makeModelContainer() -> Result<ModelContainer, Error> {
        let schema = Schema([
            RecordingSession.self,
            MeasurementSample.self,
            VideoEvidenceSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return .success(container)
        } catch {
            return .failure(error)
        }
    }
}
