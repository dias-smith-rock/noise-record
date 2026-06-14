import Foundation

let widgetPendingActionLocalNotification = Notification.Name("widget.pendingAction.local")

nonisolated func widgetPendingActionDarwinCallback(
    _: CFNotificationCenter?,
    _: UnsafeMutableRawPointer?,
    _: CFNotificationName?,
    _: UnsafeRawPointer?,
    _: CFDictionary?
) {
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: widgetPendingActionLocalNotification, object: nil)
    }
}
