import SwiftUI

extension Notification.Name {
    /// 冷启动需要展示「免广告购买」引导 Sheet 时发出。
    static let launchRemoveAdsPromoShouldPresent = Notification.Name("launchRemoveAdsPromoShouldPresent")
    /// 冷启动 Paywall 关闭后（或无需 Paywall 时）请求自动开启监测。
    static let launchAutoStartMonitoring = Notification.Name("launchAutoStartMonitoring")
    /// 新手任务：首次监测满 10 秒，应自动保存监测报告到 Files。
    static let onboardingMeasureReportDue = Notification.Name("onboardingMeasureReportDue")
}

/// Drives cold/hot-start ad presentation via SwiftUI scene lifecycle.
/// First cold start: auto-start monitoring and defer Paywall until value moment or 2nd launch.
/// Repeat cold start: show Paywall first for non-premium users, then app-open ad if dismissed.
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
    private static var pendingLaunchMonitoringAutoStart = false
    /// 冷启动 Paywall 关闭后、非 VIP 用户待展示的开屏广告。
    private static var pendingColdStartAdAfterLaunchPromoDismiss = false

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
                pendingLaunchMonitoringAutoStart = true
                AdSessionPolicy.resetSessionCounters()
                AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "launch_monitoring_auto_start_armed")

                let launchCount = LaunchExperienceStore.recordColdLaunch()
                AppTelemetry.logProductEvent(
                    "cold_launch_recorded",
                    parameters: [
                        "count": String(launchCount),
                        "first_install_day": LaunchExperienceStore.isFirstInstallDay ? "true" : "false",
                    ]
                )

                if !SubscriptionManager.isPremiumSnapshot {
                    if LaunchExperienceStore.shouldDeferLaunchPaywallOnColdStart {
                        if AdMobConfig.adsEnabled, LaunchExperienceStore.allowsAdsOnFirstInstallDay {
                            pendingPresentation = .cold
                            AppTelemetry.logAdLifecycle(channel: "cold", step: "armed_on_first_launch_deferred_paywall")
                        } else if LaunchExperienceStore.isFirstInstallDay {
                            AppTelemetry.logAdLifecycle(channel: "cold", step: "skipped_first_install_day")
                        }
                        scheduleLaunchAutoStartMonitoring()
                    } else {
                        armLaunchRemoveAdsPromo()
                    }
                } else if AdMobConfig.adsEnabled, LaunchExperienceStore.allowsAdsOnFirstInstallDay {
                    pendingPresentation = .cold
                    AppTelemetry.logAdLifecycle(channel: "cold", step: "armed_on_cold_start")
                } else if LaunchExperienceStore.isFirstInstallDay {
                    AppTelemetry.logAdLifecycle(channel: "cold", step: "skipped_first_install_day")
                }

                if SubscriptionManager.isPremiumSnapshot {
                    scheduleLaunchAutoStartMonitoring()
                }
            } else if wasInBackground {
                wasInBackground = false
                if AdMobConfig.adsEnabled, LaunchExperienceStore.allowsAdsOnFirstInstallDay {
                    pendingPresentation = .hot
                    hasPresentedSinceForeground = false
                    AppTelemetry.logAdLifecycle(channel: "hot", step: "armed_on_hot_start")
                }
            } else {
                AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "active_without_ad_trigger")
            }

            if AdMobConfig.adsEnabled, LaunchExperienceStore.allowsAdsOnFirstInstallDay {
                AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
            }

        case .background:
            wasInBackground = true
            pendingPresentation = nil
            hasPresentedSinceForeground = false
            shouldPresentLaunchRemoveAdsPromo = false
            pendingLaunchMonitoringAutoStart = false
            pendingColdStartAdAfterLaunchPromoDismiss = false
            AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "scene_entered_background")
            if AdMobConfig.adsEnabled,
               LaunchExperienceStore.allowsAdsOnFirstInstallDay,
               AdConsentManager.canRequestAds {
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

    /// 消费冷启动自动开监测令牌（每轮冷启动仅一次）。
    static func consumeLaunchMonitoringAutoStart() -> Bool {
        guard pendingLaunchMonitoringAutoStart else { return false }
        pendingLaunchMonitoringAutoStart = false
        return true
    }

    /// 通知 `ContentView` 在冷启动后自动开启监测。
    static func requestLaunchAutoStartMonitoring() {
        guard MonitorSettingsStore.autoStartMonitoringOnLaunch else { return }
        guard consumeLaunchMonitoringAutoStart() else { return }
        NotificationCenter.default.post(name: .launchAutoStartMonitoring, object: nil)
    }

    /// 延迟到下一 run loop，确保 `ContentView` 已挂载通知监听。
    static func scheduleLaunchAutoStartMonitoring() {
        Task { @MainActor in
            try? await Task.yield()
            requestLaunchAutoStartMonitoring()
        }
    }

    /// Paywall Sheet 关闭动画结束后再自动开监测，避免与 dismiss 争抢主线程。
    static func scheduleLaunchAutoStartMonitoringAfterPaywallDismiss() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            requestLaunchAutoStartMonitoring()
        }
    }

    /// 免广告购买 Sheet 关闭后：已购买则结束；未购买则排队展示冷启动开屏广告。
    static func handleLaunchRemoveAdsPromoDismissed(purchased: Bool) {
        AppTelemetry.logAdLifecycle(
            channel: "iap_promo",
            step: "sheet_dismissed",
            metadata: ["purchased": String(purchased)]
        )

        pendingPresentation = nil
        hasPresentedSinceForeground = true

        if purchased || SubscriptionManager.isPremiumSnapshot {
            pendingColdStartAdAfterLaunchPromoDismiss = false
            return
        }

        guard LaunchExperienceStore.allowsAdsOnFirstInstallDay else {
            pendingColdStartAdAfterLaunchPromoDismiss = false
            AppTelemetry.logAdLifecycle(channel: "cold", step: "skipped_first_install_day_after_paywall")
            return
        }

        pendingColdStartAdAfterLaunchPromoDismiss = true
        scheduleColdStartAdAfterLaunchPromoDismiss()
    }

    /// AdMob 同意流程与 SDK 初始化完成后，重试冷启动 Paywall 关闭后的开屏广告。
    static func notifyColdStartAdPipelineReady() {
        scheduleColdStartAdAfterLaunchPromoDismiss()
    }

    private static func scheduleColdStartAdAfterLaunchPromoDismiss() {
        guard pendingColdStartAdAfterLaunchPromoDismiss else { return }
        Task { @MainActor in
            await presentColdStartAdAfterLaunchPromoDismissIfNeeded()
        }
    }

    private static func presentColdStartAdAfterLaunchPromoDismissIfNeeded() async {
        guard pendingColdStartAdAfterLaunchPromoDismiss else { return }
        guard AdMobConfig.adsEnabled else {
            pendingColdStartAdAfterLaunchPromoDismiss = false
            return
        }
        if SubscriptionManager.isPremiumSnapshot {
            pendingColdStartAdAfterLaunchPromoDismiss = false
            return
        }

        await LaunchPerformance.whenFirstInteractive()
        AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
        await waitUntilAdsCanBeRequested(timeoutSeconds: 20)

        guard pendingColdStartAdAfterLaunchPromoDismiss else { return }
        guard AdConsentManager.canRequestAds else {
            AppTelemetry.logAdLifecycle(channel: "cold", step: "show_deferred_paywall_dismiss_waiting_consent")
            return
        }

        // 等待 Paywall Sheet 关闭动画结束，避免 rootViewController 仍被 Sheet 占用。
        try? await Task.sleep(for: .milliseconds(450))

        guard pendingColdStartAdAfterLaunchPromoDismiss else { return }
        pendingColdStartAdAfterLaunchPromoDismiss = false
        AppTelemetry.logAdLifecycle(channel: "cold", step: "show_requested_after_launch_promo_dismiss")
        AppOpenAdManager.shared.showAdIfAvailable()
    }

    private static func waitUntilAdsCanBeRequested(timeoutSeconds: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if AdConsentManager.canRequestAds { return }
            AdMobBootstrap.scheduleConsentAndAdMobStartIfNeeded()
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// 进入全屏 LED 看板后展示插屏广告（略作延迟，等待 fullScreenCover 呈现完成）。
    static func showInterstitialOnFullscreenEnter() {
        guard AdMobConfig.adsEnabled,
              LaunchExperienceStore.allowsAdsOnFirstInstallDay,
              AdConsentManager.canRequestAds else { return }

        AppTelemetry.logAdLifecycle(channel: "fullscreen_led", step: "show_requested")
        HotStartAdManager.shared.loadAd()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            AppTelemetry.logAdLifecycle(channel: "fullscreen_led", step: "show_presenting")
            HotStartAdManager.shared.showAdIfAvailable()
        }
    }

    /// Call when the user performs their first intentional action after foregrounding.
    static func recordFirstInteraction(source: String) {
        guard AdMobConfig.adsEnabled else { return }
        guard LaunchExperienceStore.allowsAdsOnFirstInstallDay else { return }
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
