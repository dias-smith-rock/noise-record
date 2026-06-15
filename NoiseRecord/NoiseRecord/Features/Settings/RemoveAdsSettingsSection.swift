import SwiftUI

/// 设置页免广告引导：Banner 入口 + 购买 Sheet。
struct RemoveAdsSettingsPromo: View {
    let theme: ModeVisualTheme

    @Bindable private var iap = IAPManager.shared
    @State private var showPurchaseSheet = false

    var body: some View {
        Group {
            if !iap.isAdsRemoved {
                RemoveAdsPromoBanner(theme: theme) {
                    showPurchaseSheet = true
                }
            }
        }
        .sheet(isPresented: $showPurchaseSheet) {
            RemoveAdsPurchaseSheet(theme: theme)
        }
    }
}

// MARK: - Banner

private struct RemoveAdsPromoBanner: View {
    let theme: ModeVisualTheme
    let onTap: () -> Void

    @Bindable private var iap = IAPManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.18)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settingsRemoveAdsBannerTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.settingsRemoveAdsBannerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(iap.removeAdsSaleDisplayPrice)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(iap.removeAdsOriginalDisplayPrice)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .strikethrough()
                        .monospacedDigit()
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [theme.accent, theme.secondaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: theme.accent.opacity(0.28), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.settingsRemoveAdsBannerTitle)
        .accessibilityHint(L10n.settingsRemoveAdsBannerSubtitle)
    }
}

// MARK: - Purchase Sheet

struct RemoveAdsPurchaseSheet: View {
    let theme: ModeVisualTheme

    @Environment(\.dismiss) private var dismiss
    @Bindable private var iap = IAPManager.shared

    @State private var showPurchasedAlert = false
    @State private var showPendingAlert = false
    @State private var showRestoredAlert = false
    @State private var showCancelledAlert = false
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var sheetDetent: PresentationDetent = .fraction(0.86)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sheetHero

                    VStack(alignment: .leading, spacing: 14) {
                        benefitRow(L10n.settingsRemoveAdsBenefitNoAppOpen)
                        benefitRow(L10n.settingsRemoveAdsBenefitNoInterstitial)
                        benefitRow(L10n.settingsRemoveAdsBenefitLifetime)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 12) {
                        priceDisplayBlock

                        ProPrimaryButton(
                            title: purchaseButtonTitle,
                            systemImage: "bag.fill",
                            tint: theme.accent
                        ) {
                            Task { await purchaseRemoveAds() }
                        }
                        .disabled(iap.isPurchasing)
                        .opacity(iap.isPurchasing ? 0.55 : 1)
                        .overlay {
                            if iap.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            }
                        }

                        Button(L10n.settingsRemoveAdsRestore) {
                            Task { await restorePurchases() }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.accent)
                        .disabled(iap.isPurchasing)
                    }

                    Text(L10n.settingsRemoveAdsFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    legalLinksRow
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.settingsRemoveAdsSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.86), .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .alert(L10n.settingsRemoveAdsPurchasedTitle, isPresented: $showPurchasedAlert) {
            Button(L10n.ok, role: .cancel) {
                dismiss()
            }
        } message: {
            Text(L10n.settingsRemoveAdsPurchasedMessage)
        }
        .alert(L10n.settingsRemoveAdsPendingTitle, isPresented: $showPendingAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.settingsRemoveAdsPendingMessage)
        }
        .alert(L10n.settingsRemoveAdsRestoredTitle, isPresented: $showRestoredAlert) {
            Button(L10n.ok, role: .cancel) {
                dismiss()
            }
        } message: {
            Text(L10n.settingsRemoveAdsRestoredMessage)
        }
        .alert(L10n.settingsRemoveAdsCancelledTitle, isPresented: $showCancelledAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.settingsRemoveAdsCancelledMessage)
        }
        .alert(L10n.settingsRemoveAdsErrorTitle, isPresented: $showErrorAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(errorAlertMessage)
        }
    }

    private var sheetHero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.title)
                .foregroundStyle(theme.accent)
                .frame(width: 52, height: 52)
                .background(theme.badgeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.settingsRemoveAdsSheetHeadline)
                    .font(.title3.bold())
                Text(L10n.settingsRemoveAdsSheetSubheadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var priceDisplayBlock: some View {
        VStack(spacing: 6) {
            Text(iap.removeAdsOriginalDisplayPrice)
                .font(.title3)
                .foregroundStyle(.secondary)
                .strikethrough()
                .monospacedDigit()

            Text(iap.removeAdsSaleDisplayPrice)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
                .monospacedDigit()

            Text(L10n.settingsRemoveAdsPriceNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                iap.isRemoveAdsProductLoaded
                    ? L10n.settingsRemoveAdsProductLoaded
                    : L10n.settingsRemoveAdsProductFallback
            )
            .font(.caption2)
            .foregroundStyle(iap.isRemoveAdsProductLoaded ? .green : .orange)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.accent)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legalLinksRow: some View {
        HStack(spacing: 16) {
            Link(L10n.settingsPrivacyPolicy, destination: LegalURLs.privacyPolicy)
            Text("·")
                .foregroundStyle(.tertiary)
            Link(L10n.settingsTermsOfService, destination: LegalURLs.termsOfService)
        }
        .font(.caption)
        .foregroundStyle(theme.accent)
        .frame(maxWidth: .infinity)
    }

    private var purchaseButtonTitle: String {
        L10n.settingsRemoveAdsPurchase(price: iap.removeAdsSaleDisplayPrice)
    }

    private func purchaseRemoveAds() async {
        do {
            switch try await iap.purchaseRemoveAds() {
            case .purchased:
                showPurchasedAlert = true
            case .pending:
                showPendingAlert = true
            case .cancelled:
                showCancelledAlert = true
            }
        } catch {
            presentError(error)
        }
    }

    private func restorePurchases() async {
        do {
            try await iap.restorePurchases()
            showRestoredAlert = true
        } catch {
            presentError(error)
        }
    }

    private func presentError(_ error: Error) {
        errorAlertMessage = error.localizedDescription
        showErrorAlert = true
    }
}
