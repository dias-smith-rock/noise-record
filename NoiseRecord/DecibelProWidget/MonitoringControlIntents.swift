import AppIntents
import Foundation

struct StartMonitoringIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.start"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.pendingAction = .start
        WidgetSnapshotStore.postPendingActionNotification()
        return .result()
    }
}

struct StopMonitoringIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.stop"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.pendingAction = .stop
        WidgetSnapshotStore.postPendingActionNotification()
        return .result()
    }
}

struct DecibelProWidgetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMonitoringIntent(),
            phrases: [
                "Start monitoring in \(.applicationName)",
                "Start noise monitoring in \(.applicationName)",
            ],
            shortTitle: "widget.intent.start",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: StopMonitoringIntent(),
            phrases: [
                "Stop monitoring in \(.applicationName)",
                "Stop noise monitoring in \(.applicationName)",
            ],
            shortTitle: "widget.intent.stop",
            systemImageName: "stop.circle"
        )
    }
}
