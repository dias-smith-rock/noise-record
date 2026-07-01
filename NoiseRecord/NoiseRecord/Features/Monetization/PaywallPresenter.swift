import SwiftUI

@Observable
@MainActor
final class PaywallPresenter {
    static let shared = PaywallPresenter()

    var isPresented = false
    var context: PaywallContext = .settings
    private var onResult: ((Bool) -> Void)?
    private var didResolve = false

    func present(context: PaywallContext, onResult: ((Bool) -> Void)? = nil) {
        self.context = context
        self.onResult = onResult
        didResolve = false
        AppTelemetry.logCommercialEvent(
            domain: "paywall",
            outcome: "shown",
            metadata: ["context": context.rawValue]
        )
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    /// `purchased` 为 true 表示用户已成为 Premium（购买或恢复成功）。
    func resolve(purchased: Bool) {
        guard !didResolve else { return }
        didResolve = true
        let handler = onResult
        onResult = nil
        isPresented = false
        handler?(purchased)
    }

    func handleSheetDismissed() {
        guard !didResolve else { return }
        guard let handler = onResult else {
            isPresented = false
            return
        }
        didResolve = true
        onResult = nil
        handler(SubscriptionManager.shared.isPremiumUser)
    }
}

struct PaywallPresenterModifier: ViewModifier {
    @Bindable private var presenter = PaywallPresenter.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $presenter.isPresented, onDismiss: {
                presenter.handleSheetDismissed()
            }) {
                PaywallView(context: presenter.context)
            }
    }
}

extension View {
    func paywallPresenter() -> some View {
        modifier(PaywallPresenterModifier())
    }
}
