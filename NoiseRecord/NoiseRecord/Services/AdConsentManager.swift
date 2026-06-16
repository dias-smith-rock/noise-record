import UserMessagingPlatform

/// Google UMP consent flow for AdMob. ATT is triggered by the IDFA explainer configured in AdMob Privacy & messaging — do not call `ATTrackingManager` manually.
@MainActor
enum AdConsentManager {
    private static var hasStartedConsentThisSession = false

    static var canRequestAds: Bool {
        UMPConsentInformation.sharedInstance.canRequestAds
    }

    static var isPrivacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    /// Runs UMP on each session when ads are enabled. Returns whether ads may be requested.
    static func gatherConsentIfNeeded() async -> Bool {
        guard AdMobConfig.adsEnabled else {
            AppTelemetry.logAdLifecycle(channel: "consent", step: "skipped_ads_disabled")
            return false
        }

        guard !hasStartedConsentThisSession else {
            return canRequestAds
        }
        hasStartedConsentThisSession = true

        AppTelemetry.logAdLifecycle(channel: "consent", step: "info_update_started")

        let parameters = makeRequestParameters()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    AppTelemetry.logAdLifecycle(
                        channel: "consent",
                        step: "info_update_failed",
                        metadata: ["error": error.localizedDescription]
                    )
                } else {
                    AppTelemetry.logAdLifecycle(
                        channel: "consent",
                        step: "info_update_completed",
                        metadata: [
                            "consent_status": String(describing: UMPConsentInformation.sharedInstance.consentStatus),
                            "form_status": String(describing: UMPConsentInformation.sharedInstance.formStatus),
                        ]
                    )
                }
                continuation.resume()
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentForm.loadAndPresentIfRequired(from: nil) { error in
                if let error {
                    AppTelemetry.logAdLifecycle(
                        channel: "consent",
                        step: "form_present_failed",
                        metadata: ["error": error.localizedDescription]
                    )
                } else {
                    AppTelemetry.logAdLifecycle(channel: "consent", step: "form_presented")
                }
                continuation.resume()
            }
        }

        let allowed = canRequestAds
        AppTelemetry.logAdLifecycle(
            channel: "consent",
            step: "can_request_ads",
            metadata: ["value": String(allowed)]
        )
        return allowed
    }

    static func presentPrivacyOptions() async throws {
        AppTelemetry.logAdLifecycle(channel: "consent", step: "privacy_options_present_started")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UMPConsentForm.presentPrivacyOptionsForm(from: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        AppTelemetry.logAdLifecycle(channel: "consent", step: "privacy_options_presented")
    }

    #if DEBUG
    static func resetForTesting() {
        UMPConsentInformation.sharedInstance.reset()
        hasStartedConsentThisSession = false
    }
    #endif

    private static func makeRequestParameters() -> UMPRequestParameters {
        let parameters = UMPRequestParameters()
        #if DEBUG
        let debugSettings = UMPDebugSettings()
        // Uncomment and set device hash from Xcode log when testing UMP in Debug builds.
        // debugSettings.testDeviceIdentifiers = ["YOUR-DEVICE-HASH"]
        // debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif
        return parameters
    }
}
