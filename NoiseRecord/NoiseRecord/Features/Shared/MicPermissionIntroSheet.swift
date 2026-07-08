import SwiftUI

struct MicPermissionIntroSheet: View {
    let theme: ModeVisualTheme
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(theme.accent)

                Text(L10n.micPermissionIntroTitle)
                    .font(.title3.bold())

                Text(L10n.micPermissionIntroBody)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    introRow(systemImage: "ear.and.waveform", text: L10n.micPermissionIntroPointMeasure)
                    introRow(systemImage: "lock.shield", text: L10n.micPermissionIntroPointLocal)
                    introRow(systemImage: "moon.zzz.fill", text: L10n.micPermissionIntroPointSleep)
                }

                Spacer(minLength: 0)

                Button(action: onContinue) {
                    Text(L10n.micPermissionIntroContinue)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                Button(L10n.close, action: onDismiss)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func introRow(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
