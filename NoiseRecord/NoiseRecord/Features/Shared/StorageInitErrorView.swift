import SwiftUI

struct StorageInitErrorView: View {
    let error: Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.errorStorageInitTitle)
                .font(.title2.bold())
            Text(L10n.errorStorageInitMessage(error.localizedDescription))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(L10n.errorStorageInitRetry, action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
