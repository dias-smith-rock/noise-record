import SwiftUI

/// Drives cold/hot-start ad presentation via SwiftUI scene lifecycle.
/// `UIApplicationDelegate.applicationDidBecomeActive` is not reliably invoked in this SwiftUI app.
@MainActor
enum AdSceneLifecycle {
    private static var isColdStart = true
    private static var wasInBackground = false

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
                Task { @MainActor in
                    await LaunchPerformance.whenFirstInteractive()
                    AppTelemetry.logAdLifecycle(channel: "cold", step: "show_requested_on_cold_start")
                    AppOpenAdManager.shared.showAdIfAvailable()
                }
            } else if wasInBackground {
                AppTelemetry.logAdLifecycle(channel: "hot", step: "show_requested_on_hot_start")
                HotStartAdManager.shared.showAdIfAvailable()
                wasInBackground = false
            } else {
                AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "active_without_ad_trigger")
            }

        case .background:
            wasInBackground = true
            AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "scene_entered_background")
            HotStartAdManager.shared.loadAd()

        case .inactive:
            AppTelemetry.logAdLifecycle(channel: "lifecycle", step: "scene_inactive")

        @unknown default:
            break
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
