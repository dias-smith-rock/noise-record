import GoogleMobileAds
import UIKit

/// Starts UMP consent (which triggers ATT via IDFA Explainer) and AdMob only after the
/// window scene is active, with a short buffer so iOS does not silently drop ATT on newer OS versions.
@MainActor
enum AdMobBootstrap {
    private static var hasScheduledConsentPipeline = false
    private static var hasCompletedConsentPipeline = false

    /// Call from `scenePhase == .active` and `UIApplication.didBecomeActiveNotification`.
    static func scheduleConsentAndAdMobStartIfNeeded() {
        guard AdMobConfig.adsEnabled else {
            AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "pipeline_skipped_ads_disabled")
            return
        }
        guard LaunchExperienceStore.allowsAdsOnFirstInstallDay else {
            AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "pipeline_skipped_first_install_day")
            return
        }
        guard !hasScheduledConsentPipeline else { return }
        hasScheduledConsentPipeline = true

        AppTelemetry.logAdLifecycle(
            channel: "bootstrap",
            step: "consent_pipeline_scheduled",
            metadata: ["delay_seconds": String(AdMobConfig.consentPresentationDelaySeconds)]
        )

        Task { @MainActor in
            await waitUntilScenePresentationReady()
            await runConsentAndAdMobStart()
        }
    }

    private static func waitUntilScenePresentationReady() async {
        try? await Task.sleep(for: .seconds(AdMobConfig.consentPresentationDelaySeconds))

        for attempt in 0..<20 {
            let hasForegroundScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .contains { $0.activationState == .foregroundActive }

            if hasForegroundScene {
                AppTelemetry.logAdLifecycle(
                    channel: "bootstrap",
                    step: "presentation_ready",
                    metadata: ["attempt": String(attempt)]
                )
                return
            }

            try? await Task.sleep(for: .milliseconds(50))
        }

        AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "presentation_ready_timeout")
    }

    private static func runConsentAndAdMobStart() async {
        guard !hasCompletedConsentPipeline else { return }

        guard await AdConsentManager.gatherConsentIfNeeded() else {
            AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "pipeline_stopped_no_consent")
            return
        }

        hasCompletedConsentPipeline = true
        startAdMob()
    }

    static func startAdMob() {
        guard AdMobConfig.adsEnabled else {
            AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "admob_skipped_debug")
            return
        }

        guard AdConsentManager.canRequestAds else {
            AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "admob_skipped_no_consent")
            return
        }

        LaunchPerformance.mark(.launchAdMobStartRequested)
        AppTelemetry.logAdLifecycle(channel: "bootstrap", step: "admob_start_requested")

        // Default ads to muted so fullscreen video does not interrupt monitoring / device audio.
        MobileAds.shared.isApplicationMuted = true
        MobileAds.shared.applicationVolume = 0

        MobileAds.shared.start { status in
            Task { @MainActor in
                // Re-assert mute after SDK init in case adapters reset audio state.
                MobileAds.shared.isApplicationMuted = true
                MobileAds.shared.applicationVolume = 0
                LaunchPerformance.mark(.launchAdMobStartCompleted)
                AppTelemetry.logAdLifecycle(
                    channel: "bootstrap",
                    step: "admob_start_completed",
                    metadata: [
                        "adapter_count": String(status.adapterStatusesByClassName.count),
                    ]
                )
                for (adapter, adapterStatus) in status.adapterStatusesByClassName {
                    AppTelemetry.logAdLifecycle(
                        channel: "bootstrap",
                        step: "admob_adapter_status",
                        metadata: [
                            "adapter": adapter,
                            "state": String(describing: adapterStatus.state),
                            "description": adapterStatus.description,
                        ]
                    )
                }
                AppOpenAdManager.shared.loadAd()
                HotStartAdManager.shared.loadAd()
                AdSceneLifecycle.notifyColdStartAdPipelineReady()
            }
        }
    }
}
