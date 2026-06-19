import SwiftUI

/// 冷启动时：未购买免广告则自动弹出购买 Sheet；关闭且仍未购买时由 `AdSceneLifecycle` 展示开屏广告。
private struct LaunchRemoveAdsPromoModifier: ViewModifier {
    @State private var showPurchaseSheet = false
    @Bindable private var iap = IAPManager.shared

    private var theme: ModeVisualTheme {
        .theme(for: .standard)
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: presentLaunchPromoIfNeeded)
            .onReceive(
                NotificationCenter.default.publisher(for: .launchRemoveAdsPromoShouldPresent)
            ) { _ in
                presentLaunchPromoIfNeeded()
            }
            .sheet(isPresented: $showPurchaseSheet, onDismiss: handlePurchaseSheetDismissed) {
                RemoveAdsPurchaseSheet(theme: theme)
            }
    }

    private func presentLaunchPromoIfNeeded() {
        guard !iap.isAdsRemoved else { return }
        guard AdSceneLifecycle.consumeLaunchRemoveAdsPromoPresentation() else { return }
        showPurchaseSheet = true
        AppTelemetry.logAdLifecycle(channel: "iap_promo", step: "sheet_presented")
    }

    private func handlePurchaseSheetDismissed() {
        AdSceneLifecycle.handleLaunchRemoveAdsPromoDismissed(purchased: iap.isAdsRemoved)
    }
}

extension View {
    func launchRemoveAdsPromo() -> some View {
        modifier(LaunchRemoveAdsPromoModifier())
    }
}
