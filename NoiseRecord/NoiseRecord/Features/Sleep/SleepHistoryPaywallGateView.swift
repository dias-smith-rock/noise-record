import SwiftUI

struct SleepHistoryPaywallGateView: View {
    var body: some View {
        ContentUnavailableView(
            L10n.sleepHistoryTitle,
            systemImage: "lock.fill",
            description: Text(L10n.paywallContextSleepHistory)
        )
        .onAppear {
            PaywallPresenter.shared.present(context: .sleepHistory)
        }
    }
}
