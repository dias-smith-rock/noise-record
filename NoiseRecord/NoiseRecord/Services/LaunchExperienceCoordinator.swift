import SwiftUI

@MainActor
enum LaunchExperienceCoordinator {
    static func presentDeferredLaunchPaywall(trigger: String) {
        guard !SubscriptionManager.shared.isPremiumUser else { return }
        guard !LaunchExperienceStore.hasShownLaunchPaywall else { return }

        LaunchExperienceStore.markLaunchPaywallShown()
        AppTelemetry.logProductEvent(
            "launch_paywall_presented",
            parameters: ["trigger": trigger]
        )

        PaywallPresenter.shared.present(context: .launch) { purchased in
            handleLaunchPaywallDismissed(purchased: purchased, trigger: trigger)
        }
    }

    static func presentColdStartLaunchPaywallIfArmed() -> Bool {
        guard !SubscriptionManager.shared.isPremiumUser else { return false }
        guard AdSceneLifecycle.consumeLaunchRemoveAdsPromoPresentation() else { return false }

        LaunchExperienceStore.markLaunchPaywallShown()
        AppTelemetry.logProductEvent(
            "launch_paywall_presented",
            parameters: ["trigger": "cold_start_repeat"]
        )

        PaywallPresenter.shared.present(context: .launch) { purchased in
            handleLaunchPaywallDismissed(purchased: purchased, trigger: "cold_start_repeat")
        }
        return true
    }

    private static func handleLaunchPaywallDismissed(purchased: Bool, trigger: String) {
        AdSceneLifecycle.handleLaunchRemoveAdsPromoDismissed(purchased: purchased)
        AdSceneLifecycle.scheduleLaunchAutoStartMonitoringAfterPaywallDismiss()
        AppTelemetry.logProductEvent(
            "launch_paywall_dismissed",
            parameters: [
                "trigger": trigger,
                "purchased": purchased ? "true" : "false",
            ]
        )
    }
}
