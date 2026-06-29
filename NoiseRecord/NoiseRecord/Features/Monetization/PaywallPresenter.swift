import SwiftUI

@Observable
@MainActor
final class PaywallPresenter {
    static let shared = PaywallPresenter()

    var isPresented = false
    var context: PaywallContext = .settings

    func present(context: PaywallContext) {
        self.context = context
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
}

struct PaywallPresenterModifier: ViewModifier {
    @Bindable private var presenter = PaywallPresenter.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $presenter.isPresented) {
                PaywallView(context: presenter.context)
            }
    }
}

extension View {
    func paywallPresenter() -> some View {
        modifier(PaywallPresenterModifier())
    }
}
