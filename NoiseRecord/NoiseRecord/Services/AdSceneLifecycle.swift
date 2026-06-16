import SwiftUI

/// Drives cold/hot-start ad presentation via SwiftUI scene lifecycle.
/// Ads are armed on foreground but shown only after the first user interaction.
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

    static func handleScenePhase(_ phase: ScenePhase) {
        guard AdMobConfig.adsEnabled else { return }

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
                pendingPresentation = .cold
                hasPresentedSinceForeground = false
                AppTelemetry.logAdLifecycle(channel: "cold", step: "armed_on_cold_start")
            } else if wasInBackground {
                wasInBackground = false
                pendingPresentation = .hot
                hasPresentedSinceForeground = false
                AppTelemetry.logAdLifecycle(channel: "hot", step: "armed_on_hot_start")
            } else {
                AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "active_without_ad_trigger")
            }

        case .background:
            wasInBackground = true
            pendingPresentation = nil
            hasPresentedSinceForeground = false
            AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "scene_entered_background")
            if AdConsentManager.canRequestAds {
                HotStartAdManager.shared.loadAd()
            }

        case .inactive:
            AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "scene_inactive")

        @unknown default:
            break
        }
    }

    /// Call when the user performs their first intentional action after foregrounding.
    static func recordFirstInteraction(source: String) {
        guard AdMobConfig.adsEnabled else { return }
        guard AdConsentManager.canRequestAds else { return }
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
