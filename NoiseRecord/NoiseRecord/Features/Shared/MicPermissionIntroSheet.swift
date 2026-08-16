import SwiftUI

struct MicPermissionIntroSheet: View {
    let theme: ModeVisualTheme
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(theme.accent)

                        Text(L10n.micPermissionIntroTitle)
                            .font(.title3.bold())
                            .fixedSize(horizontal: false, vertical: true)

                        Text(L10n.micPermissionIntroBody)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 12) {
                            introRow(systemImage: "ear.and.waveform", text: L10n.micPermissionIntroPointMeasure)
                            introRow(systemImage: "lock.shield", text: L10n.micPermissionIntroPointLocal)
                            introRow(systemImage: "moon.zzz.fill", text: L10n.micPermissionIntroPointSleep)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }

                VStack(spacing: 8) {
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
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func introRow(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 22, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
