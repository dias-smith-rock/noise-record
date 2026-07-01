import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    let context: PaywallContext

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
                VStack(alignment: .leading, spacing: 22) {
                    heroSection
                    if subscriptions.isEarlySupporter {
                        earlySupporterBanner
                    }
                    if let subtitle = contextSubtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    benefitsSection
                    tierCardsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
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
                    Button(L10n.close) { paywallPresenter.resolve(purchased: false) }
                        .foregroundStyle(.white.opacity(0.85))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.settingsRemoveAdsRestore) {
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
        .task {
            await subscriptions.refreshIntroductoryOfferEligibility()
        }
        .alert(L10n.paywallPurchasedTitle, isPresented: $showPurchasedAlert) {
            Button(L10n.ok) { paywallPresenter.resolve(purchased: true) }
        } message: {
            Text(L10n.paywallPurchasedMessage)
        }
        .alert(L10n.settingsRemoveAdsPendingTitle, isPresented: $showPendingAlert) {
            Button(L10n.ok) { }
        } message: {
            Text(L10n.settingsRemoveAdsPendingMessage)
        }
        .alert(L10n.settingsRemoveAdsRestoredTitle, isPresented: $showRestoredAlert) {
            Button(L10n.ok) { paywallPresenter.resolve(purchased: subscriptions.isPremiumUser) }
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
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.paywallTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, accent, .yellow.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text(L10n.paywallHeadline)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.top, 8)
    }

    private var earlySupporterBanner: some View {
        Text(L10n.paywallEarlySupporterMessage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(accent.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(accent.opacity(0.55), lineWidth: 1)
                    )
            )
    }

    private var contextSubtitle: String? {
        switch context {
        case .videoEvidence: L10n.paywallContextVideo
        case .aiFilter: L10n.paywallContextAI
        case .advancedFFT: L10n.paywallContextSpectrum
        case .voiceDurationLimit: L10n.paywallContextVoiceDuration
        case .videoDailyLimit: L10n.paywallContextVideoDaily
        case .videoDurationLimit: L10n.paywallContextVideoDuration
        case .launch, .settings: nil
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(L10n.paywallBenefitVoiceUnlimited, icon: "mic.badge.plus")
            benefitRow(L10n.paywallBenefitVideo, icon: "video.badge.checkmark")
            benefitRow(L10n.paywallBenefitAI, icon: "waveform.badge.magnifyingglass")
            benefitRow(L10n.paywallBenefitNoAds, icon: "sparkles")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func benefitRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var tierCardsSection: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(SubscriptionTier.allCases) { tier in
                tierCard(tier)
            }
        }
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        let isYearly = tier == .yearly

        return Button {
            selectedTier = tier
        } label: {
            VStack(spacing: 5) {
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Group {
                    if let secondary = subscriptions.secondaryDisplayText(for: tier) {
                        Text(secondary)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    } else {
                        Text(" ")
                            .font(.system(size: 9))
                    }
                }
                .frame(minHeight: 24)
            }
            .frame(maxWidth: .infinity, minHeight: 118)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isYearly ? accent.opacity(0.12) : Color.white.opacity(0.05))
                    .shadow(color: isYearly && isSelected ? glow : .clear, radius: 10, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? accent : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(accent)
                        .padding(6)
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
            .frame(height: 16)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                if subscriptions.shouldPresentFreeTrial(for: selectedTier) {
                    Text(L10n.paywallTrialDisclaimer(days: subscriptions.introductoryTrialDays(for: selectedTier)))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else {
                    legalFooter
                        .padding(.horizontal, 20)
                }

                Button {
                    Task { await purchaseSelectedTier() }
                } label: {
                    Group {
                        if subscriptions.isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text(subscriptions.purchaseButtonTitle(for: selectedTier))
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(subscriptions.isPurchasing || subscriptions.isRefreshingIntroductoryEligibility)
                .padding(.horizontal, 20)

                Text(subscriptions.purchaseButtonSubtitle(for: selectedTier))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                legalLinks
                    .padding(.top, 4)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
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

    private var legalLinks: some View {
        HStack(spacing: 20) {
            legalExternalLink(L10n.settingsPrivacyPolicy, url: LegalURLs.privacyPolicy)
            legalExternalLink(L10n.settingsTermsOfService, url: LegalURLs.termsOfService)
        }
        .font(.caption.weight(.medium))
        .frame(maxWidth: .infinity)
    }

    private func legalExternalLink(_ title: String, url: URL) -> some View {
        Button(title) {
            UIApplication.shared.open(url)
        }
        .foregroundStyle(.white.opacity(0.6))
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
