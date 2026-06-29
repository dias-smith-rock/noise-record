import SwiftUI

/// 设置页 Pro 升级引导：Banner 入口 + PaywallView。
struct RemoveAdsSettingsPromo: View {
    let theme: ModeVisualTheme

    @Bindable private var subscriptions = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        Group {
            if !subscriptions.isPremiumUser {
                ProUpgradeBanner(theme: theme) {
                    showPaywall = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .settings)
        }
    }
}

private struct ProUpgradeBanner: View {
    let theme: ModeVisualTheme
    let onTap: () -> Void

    @Bindable private var subscriptions = SubscriptionManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.18)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.paywallUpgradeBannerTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.paywallUpgradeBannerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if subscriptions.hasRemovedAds {
                    Text(L10n.noAdsBadge)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.orange, theme.accent, Color(red: 0.9, green: 0.35, blue: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.orange.opacity(0.28), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.paywallUpgradeBannerTitle)
    }
}

/// Legacy alias — settings now opens PaywallView.