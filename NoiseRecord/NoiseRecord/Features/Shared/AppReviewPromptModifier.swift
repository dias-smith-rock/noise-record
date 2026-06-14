import StoreKit
import SwiftUI

extension View {
    func appReviewPrompt(isPresented: Binding<Bool>) -> some View {
        modifier(AppReviewPromptModifier(isPresented: isPresented))
    }
}

private struct AppReviewPromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.alert(L10n.appReviewPromptTitle, isPresented: $isPresented) {
            Button(L10n.appReviewRateNow) {
                AppReviewPresenter.requestReview(using: requestReview)
            }
            Button(L10n.appReviewLater, role: .cancel) {}
        } message: {
            Text(L10n.appReviewPromptMessage)
        }
    }
}
