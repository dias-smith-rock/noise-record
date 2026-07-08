import SwiftUI

struct LaunchPaywallPromoModifier: ViewModifier {
    @Bindable private var subscriptions = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(for: .launchRemoveAdsPromoShouldPresent)
            ) { _ in
                presentPaywallIfNeeded()
            }
            .onAppear(perform: presentPaywallIfNeeded)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                presentPaywallIfNeeded()
            }
    }

    private func presentPaywallIfNeeded() {
        guard !subscriptions.isPremiumUser else { return }
        _ = LaunchExperienceCoordinator.presentColdStartLaunchPaywallIfArmed()
    }
}

extension View {
    func launchRemoveAdsPromo() -> some View {
        modifier(LaunchPaywallPromoModifier())
    }
}
