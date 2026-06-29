import SwiftUI

private struct LaunchPaywallPromoModifier: ViewModifier {
    @Bindable private var subscriptions = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPaywall = false

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
            .sheet(isPresented: $showPaywall, onDismiss: handleDismiss) {
                PaywallView(context: .launch)
            }
    }

    private func presentPaywallIfNeeded() {
        guard !subscriptions.isPremiumUser else { return }
        guard AdSceneLifecycle.consumeLaunchRemoveAdsPromoPresentation() else { return }
        showPaywall = true
    }

    private func handleDismiss() {
        AdSceneLifecycle.handleLaunchRemoveAdsPromoDismissed(
            purchased: subscriptions.isPremiumUser || subscriptions.hasRemovedAds
        )
        AdSceneLifecycle.scheduleLaunchAutoStartMonitoring()
    }
}

extension View {
    func launchRemoveAdsPromo() -> some View {
        modifier(LaunchPaywallPromoModifier())
    }
}
