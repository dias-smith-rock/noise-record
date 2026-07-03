import SwiftUI

struct LocationAccessGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.settingsLocationAccessGuideStep1)
                    Text(L10n.settingsLocationAccessGuideStep2)
                    Text(L10n.settingsLocationAccessGuideStep3)
                } header: {
                    Text(L10n.settingsLocationAccessGuideHeader)
                } footer: {
                    Text(L10n.settingsLocationAccessGuideFooter)
                }
            }
            .navigationTitle(L10n.settingsLocationAccessGuideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.permissionOpenSettings) {
                        PermissionSettings.openAppSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}
