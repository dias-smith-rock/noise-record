import SwiftUI
import UIKit

enum PermissionSettings {
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct PermissionDeniedAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            Button(L10n.permissionOpenSettings) {
                PermissionSettings.openSystemSettings()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

extension View {
    func permissionDeniedAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String
    ) -> some View {
        modifier(PermissionDeniedAlertModifier(isPresented: isPresented, title: title, message: message))
    }
}
