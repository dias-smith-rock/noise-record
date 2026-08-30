import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @Bindable private var subscriptions = SubscriptionManager.shared
    @Bindable private var paywallPresenter = PaywallPresenter.shared

    @State private var selectedTier: SubscriptionTier = .yearly
    @State private var showPurchasedAlert = false
    @State private var showPendingAlert = false
    @State private var showRestoredAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let accent = Color.orange
    private let glow = Color.orange.opacity(0.45)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heroSection
                    if subscriptions.isEarlySupporter {
                        earlySupporterBanner
                    }
                    // Pricing first so amounts stay above the sticky footer without scrolling.
                    tierCardsSection
                    benefitsSection
                    weeklyFreeTip
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                stickyContinueFooter
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.08, green: 0.04, blue: 0.02),
                        Color.black,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.close) {
                        AppTelemetry.logProductEvent(
                            "paywall_close_tap",
                            parameters: [
                                "context": context.rawValue,
                                "trigger_feature": paywallPresenter.triggerFeature,
                            ]
                        )
                        closePaywall(purchased: false)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.settingsRemoveAdsRestore) {
                        AppTelemetry.logProductEvent(
                            "paywall_restore_tap",
                            parameters: [
                                "context": context.rawValue,
                                "trigger_feature": paywallPresenter.triggerFeature,
                            ]
                        )
                        Task { await restorePurchases() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .disabled(subscriptions.isPurchasing)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .debugView("paywall")
        .debugPresentation("paywall") {
            closePaywall(purchased: false)
        }
        .debugAction("dismiss_paywall") {
            closePaywall(purchased: false)
        }
        .task {
            await subscriptions.refreshIntroductoryOfferEligibility()
        }
        .alert(L10n.paywallPurchasedTitle, isPresented: $showPurchasedAlert) {
            Button(L10n.ok) { closePaywall(purchased: true) }
        } message: {
            Text(L10n.paywallPurchasedMessage)
        }
        .alert(L10n.settingsRemoveAdsPendingTitle, isPresented: $showPendingAlert) {
            Button(L10n.ok) { }
        } message: {
            Text(L10n.settingsRemoveAdsPendingMessage)
        }
        .alert(L10n.settingsRemoveAdsRestoredTitle, isPresented: $showRestoredAlert) {
            Button(L10n.ok) { closePaywall(purchased: subscriptions.isPremiumUser) }
        } message: {
            Text(L10n.settingsRemoveAdsRestoredMessage)
        }
        .alert(L10n.settingsRemoveAdsErrorTitle, isPresented: $showErrorAlert) {
            Button(L10n.ok) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heroTitle)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, accent, .yellow.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text(heroHeadline)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var earlySupporterBanner: some View {
        Text(L10n.paywallEarlySupporterMessage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accent.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(accent.opacity(0.55), lineWidth: 1)
                    )
            )
    }

    private var heroTitle: String {
        switch context {
        case .mediaPreviewLimit: L10n.paywallTitlePreview
        case .mediaExport: L10n.paywallTitleExport
        case .sleepExport: L10n.paywallTitleSleepExport
        case .aiFilter: L10n.paywallTitleAI
        case .launch, .settings: L10n.paywallTitle
        case .videoEvidence, .videoDailyLimit, .videoDurationLimit,
             .voiceDurationLimit, .advancedFFT, .sleepHistory:
            L10n.paywallTitle
        }
    }

    private var heroHeadline: String {
        switch context {
        case .mediaPreviewLimit: L10n.paywallContextMediaPreviewLimit
        case .mediaExport: L10n.paywallContextMediaExport
        case .sleepExport: L10n.paywallContextSleepExport
        case .aiFilter: L10n.paywallContextAI
        case .launch, .settings: L10n.paywallHeadline
        case .videoEvidence: L10n.paywallContextVideo
        case .videoDailyLimit: L10n.paywallContextVideoDaily
        case .videoDurationLimit: L10n.paywallContextVideoDuration
        case .voiceDurationLimit: L10n.paywallContextVoiceDuration
        case .advancedFFT: L10n.paywallContextSpectrum
        case .sleepHistory: L10n.paywallContextSleepHistory
        }
    }

    private var primaryCTATitle: String {
        if subscriptions.shouldPresentFreeTrial(for: selectedTier) {
            return L10n.paywallCTAStartFreeTrial(
                days: subscriptions.introductoryTrialDays(for: selectedTier)
            )
        }
        switch context {
        case .mediaPreviewLimit:
            return L10n.paywallCTAUnlockPlayback
        case .mediaExport:
            return L10n.paywallCTAUnlockExport
        case .sleepExport:
            return L10n.paywallCTAUnlockCleanPDF
        default:
            return L10n.paywallCTASubscribeNow
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(L10n.paywallBenefitFullPlayback, icon: "play.circle.fill")
            benefitRow(L10n.paywallBenefitExportShare, icon: "square.and.arrow.up")
            benefitRow(L10n.paywallBenefitSleepReport, icon: "doc.richtext.fill")
            benefitRow(L10n.paywallBenefitAI, icon: "waveform.badge.magnifyingglass")
            benefitRow(L10n.paywallBenefitNoAds, icon: "sparkles")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var weeklyFreeTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
            Text(L10n.paywallWeeklyFreeTip)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accent.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: glow.opacity(0.35), radius: 10, y: 2)
        .accessibilityElement(children: .combine)
    }

    private func benefitRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tierCardsSection: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(SubscriptionTier.allCases) { tier in
                tierCard(tier)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        let isYearly = tier == .yearly

        return Button {
            selectedTier = tier
        } label: {
            VStack(spacing: 6) {
                if isYearly {
                    Text(L10n.paywallBestValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent))
                } else {
                    Color.clear.frame(height: 18)
                }

                Text(tierTitle(tier))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subscriptions.primaryDisplayText(for: tier))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isYearly ? accent : .white)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if let secondary = subscriptions.secondaryDisplayText(for: tier) {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(" ")
                            .font(.caption2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isYearly ? accent.opacity(0.12) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? accent : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .background {
                if isYearly && isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clear)
                        .shadow(color: glow, radius: 8, y: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(accent)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func tierTitle(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .weekly: L10n.paywallTierWeekly
        case .monthly: L10n.paywallTierMonthly
        case .yearly: L10n.paywallTierYearly
        }
    }

    private var stickyContinueFooter: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.92), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 12)
            .allowsHitTesting(false)

            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    if subscriptions.shouldPresentFreeTrial(for: selectedTier) {
                        Text(L10n.paywallTrialDisclaimer(days: subscriptions.introductoryTrialDays(for: selectedTier)))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    } else {
                        legalFooter
                    }
                    compactLegalLinks
                }
                .padding(.horizontal, 20)

                Button {
                    AppTelemetry.logProductEvent(
                        "paywall_purchase_tap",
                        parameters: [
                            "context": context.rawValue,
                            "trigger_feature": paywallPresenter.triggerFeature,
                            "tier": selectedTier.rawValue,
                        ]
                    )
                    Task { await purchaseSelectedTier() }
                } label: {
                    Group {
                        if subscriptions.isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text(primaryCTATitle)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(subscriptions.isPurchasing || subscriptions.isRefreshingIntroductoryEligibility)
                .padding(.horizontal, 20)

                Text(subscriptions.purchaseButtonSubtitle(for: selectedTier))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            .background(Color.black)
        }
    }

    private var legalFooter: some View {
        Text(L10n.paywallLegalFooter)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var compactLegalLinks: some View {
        HStack(spacing: 0) {
            legalExternalLink(L10n.settingsPrivacyPolicy, url: LegalURLs.privacyPolicy, link: "privacy")
            Text("·")
                .foregroundStyle(.white.opacity(0.28))
                .padding(.horizontal, 6)
            legalExternalLink(L10n.settingsTermsOfService, url: LegalURLs.termsOfService, link: "terms")
        }
        .font(.caption2.weight(.medium))
    }

    private func legalExternalLink(_ title: String, url: URL, link: String) -> some View {
        Button(title) {
            AppTelemetry.logProductEvent(
                "paywall_legal_link_tap",
                parameters: [
                    "context": context.rawValue,
                    "link": link,
                ]
            )
            UIApplication.shared.open(url)
        }
        .foregroundStyle(.white.opacity(0.45))
    }

    private func closePaywall(purchased: Bool) {
        dismiss()
        Task { @MainActor in
            paywallPresenter.resolve(purchased: purchased)
        }
    }

    private func purchaseSelectedTier() async {
        do {
            let result = try await subscriptions.purchase(tier: selectedTier)
            switch result {
            case .purchased:
                if subscriptions.isPremiumUser {
                    showPurchasedAlert = true
                } else {
                    errorMessage = L10n.iapErrorEntitlementNotGranted
                    showErrorAlert = true
                }
            case .pending:
                showPendingAlert = true
            case .cancelled:
                break
            }
        } catch let error as SubscriptionManagerError where error == .entitlementNotGranted {
            errorMessage = L10n.iapErrorEntitlementNotGranted
            showErrorAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptions.restorePurchases()
            showRestoredAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
