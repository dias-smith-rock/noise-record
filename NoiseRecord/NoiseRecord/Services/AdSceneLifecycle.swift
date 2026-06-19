import SwiftUI

extension Notification.Name {
    /// 冷启动需要展示「免广告购买」引导 Sheet 时发出。
    static let launchRemoveAdsPromoShouldPresent = Notification.Name("launchRemoveAdsPromoShouldPresent")
}

/// Drives cold/hot-start ad presentation via SwiftUI scene lifecycle.
/// Cold start without IAP: show remove-ads sheet first; if dismissed without purchase, show app-open ad.
/// Hot start and post-purchase cold start still use first-interaction ad presentation.
/// `UIApplicationDelegate.applicationDidBecomeActive` is not reliably invoked in this SwiftUI app.
@MainActor
enum AdSceneLifecycle {
    private enum PendingPresentation {
        case cold
        case hot
    }

    private static var isColdStart = true
    private static var wasInBackground = false
    private static var pendingPresentation: PendingPresentation?
    private static var hasPresentedSinceForeground = false
    private static var shouldPresentLaunchRemoveAdsPromo = false

    /// 是否应在当前冷启动展示免广告购买 Sheet（读取后由 `consumeLaunchRemoveAdsPromoPresentation` 消费）。
    static var isLaunchRemoveAdsPromoPending: Bool {
        shouldPresentLaunchRemoveAdsPromo
    }

    static func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            AppTelemetry.logAdLifecycle(
                channel: "lifecycle",
                step: "scene_became_active",
                metadata: [
                    "is_cold_start": String(isColdStart),
                    "was_in_background": String(wasInBackground),
                ]
            )

            if isColdStart {
                isColdStart = false
                hasPresentedSinceForeground = false

                if !IAPManager.adsRemovedSnapshot {
                    armLaunchRemoveAdsPromo()
                } else if AdMobConfig.adsEnabled {
                    pendingPresentation = .cold
                    AppTelemetry.logAdLifecycle(channel: "cold", step: "armed_on_cold_start")
                }
            } else if wasInBackground {
                wasInBackground = false
                if AdMobConfig.adsEnabled {
                    pendingPresentation = .hot
                    hasPresentedSinceForeground = false
                    AppTelemetry.logAdLifecycle(channel: "hot", step: "armed_on_hot_start")
                }
            } else {
                AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "active_without_ad_trigger")
            }

            if AdMobConfig.adsEnabled {
                AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
            }

        case .background:
            wasInBackground = true
            pendingPresentation = nil
            hasPresentedSinceForeground = false
            shouldPresentLaunchRemoveAdsPromo = false
            AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "scene_entered_background")
            if AdMobConfig.adsEnabled, AdConsentManager.canRequestAds {
                HotStartAdManager.shared.loadAd()
            }

        case .inactive:
            AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "scene_inactive")

        @unknown default:
            break
        }
    }

    private static func armLaunchRemoveAdsPromo() {
        shouldPresentLaunchRemoveAdsPromo = true
        AppTelemetry.logAdLifecycle(channel: "iap_promo", step: "armed_on_cold_start")
        NotificationCenter.default.post(name: .launchRemoveAdsPromoShouldPresent, object: nil)
    }

    /// 消费一次性冷启动购买引导展示令牌。
    static func consumeLaunchRemoveAdsPromoPresentation() -> Bool {
        guard shouldPresentLaunchRemoveAdsPromo else { return false }
        shouldPresentLaunchRemoveAdsPromo = false
        return true
    }

    /// 免广告购买 Sheet 关闭后：已购买则结束；未购买则立即尝试展示冷启动开屏广告。
    static func handleLaunchRemoveAdsPromoDismissed(purchased: Bool) {
        AppTelemetry.logAdLifecycle(
            channel: "iap_promo",
            step: "sheet_dismissed",
            metadata: ["purchased": String(purchased)]
        )

        if purchased {
            pendingPresentation = nil
            hasPresentedSinceForeground = true
            return
        }

        pendingPresentation = nil
        hasPresentedSinceForeground = true

        guard AdMobConfig.adsEnabled, AdConsentManager.canRequestAds else { return }

        Task { @MainActor in
            await LaunchPerformance.whenFirstInteractive()
            AppTelemetry.logAdLifecycle(channel: "cold", step: "show_requested_after_launch_promo_dismiss")
            AppOpenAdManager.shared.showAdIfAvailable()
        }
    }

    /// Call when the user performs their first intentional action after foregrounding.
    static func recordFirstInteraction(source: String) {
        guard AdMobConfig.adsEnabled else { return }
        guard AdConsentManager.canRequestAds else { return }
        guard !shouldPresentLaunchRemoveAdsPromo else { return }
        guard !hasPresentedSinceForeground, let pending = pendingPresentation else { return }

        pendingPresentation = nil
        hasPresentedSinceForeground = true

        AppTelemetry.logAdLifecycle(
            channel: "interaction",
            step: "first_interaction",
            metadata: [
                "source": source,
                "presentation": pending == .cold ? "cold" : "hot",
            ]
        )

        Task { @MainActor in
            switch pending {
            case .cold:
                await LaunchPerformance.whenFirstInteractive()
                AppTelemetry.logAdLifecycle(channel: "cold", step: "show_requested_on_first_interaction")
                AppOpenAdManager.shared.showAdIfAvailable()
            case .hot:
                AppTelemetry.logAdLifecycle(channel: "hot", step: "show_requested_on_first_interaction")
                HotStartAdManager.shared.showAdIfAvailable()
            }
        }
    }
}

private struct AdSceneLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                AdSceneLifecycle.handleScenePhase(scenePhase)
            }
            .onChange(of: scenePhase) { _, phase in
                AdSceneLifecycle.handleScenePhase(phase)
            }
    }
}

extension View {
    func adSceneLifecycle() -> some View {
        modifier(AdSceneLifecycleModifier())
    }
}
