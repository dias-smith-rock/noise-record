import CoreLocation
import SwiftUI
import UIKit

enum PermissionSettings {
    /// Opens this app's page in the iOS Settings app (Location, Microphone, etc.).
    @MainActor
    static func openAppSettings() {
        let candidates = appSettingsURLCandidates()
        openURLCandidates(candidates)
    }

    /// Location row in Settings: request authorization first if needed, otherwise open app settings.
    @MainActor
    static func openLocationAccessSettings() {
        let status = CLLocationManager().authorizationStatus
        if status == .notDetermined {
            CLLocationManager().requestWhenInUseAuthorization()
            return
        }
        openAppSettings()
    }

    @MainActor
    static func openSystemSettings() {
        openAppSettings()
    }

    @MainActor
    private static func appSettingsURLCandidates() -> [URL] {
        guard let official = URL(string: UIApplication.openSettingsURLString) else { return [] }
        return [official]
    }

    @MainActor
    private static func openURLCandidates(_ candidates: [URL]) {
        guard let url = candidates.first else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

struct PermissionDeniedAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    var onCancel: (() -> Void)?

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            Button(L10n.permissionOpenSettings) {
                PermissionSettings.openAppSettings()
            }
            Button(L10n.cancel, role: .cancel) {
                onCancel?()
            }
        } message: {
            Text(message)
        }
    }
}

extension View {
    func permissionDeniedAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(
            PermissionDeniedAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                onCancel: onCancel
            )
        )
    }
}
