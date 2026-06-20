import SwiftUI

@main
struct NoiseRecordWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchMonitorView()
            }
            .environment(\.locale, Locale(identifier: "en"))
        }
    }
}
