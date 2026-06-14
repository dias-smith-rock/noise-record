import Foundation

private final class WidgetPendingActionObserverToken: NSObject {}

@MainActor
enum WidgetPendingActionHandler {
    private static var observerInstalled = false
    private static var pendingActionHandler: (() -> Void)?
    private static let observerToken = WidgetPendingActionObserverToken()
    private static var notificationObserver: NSObjectProtocol?

    static func install(actionHandler: @escaping () -> Void) {
        pendingActionHandler = actionHandler
        guard !observerInstalled else { return }
        observerInstalled = true

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(observerToken).toOpaque(),
            widgetPendingActionDarwinCallback,
            WidgetDarwinNotifications.pendingActionName as CFString,
            nil,
            .deliverImmediately
        )

        notificationObserver = NotificationCenter.default.addObserver(
            forName: widgetPendingActionLocalNotification,
            object: nil,
            queue: .main
        ) { _ in
            pendingActionHandler?()
        }
    }

    static func processPendingAction(
        engine: NoiseMonitorEngine,
        shouldStart: Bool,
        navigateToMonitor: () -> Void
    ) {
        guard let action = WidgetSnapshotStore.pendingAction else { return }
        WidgetSnapshotStore.pendingAction = nil
        navigateToMonitor()

        switch action {
        case .start where shouldStart:
            Task { await engine.requestPermissionAndStart() }
        case .stop:
            if engine.isMonitoring {
                engine.stopMonitoring()
                WidgetSnapshotPublisher.publishStoppedState(from: engine)
            }
        default:
            break
        }
    }
}
