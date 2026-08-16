import Foundation

/// Persists completion of the first-launch mic → camera → (later) location ladder.
nonisolated enum FirstLaunchPermissionStore {
    private static let completedKey = "permission.firstLaunchLadder.completed"

    static let ladderDidFinishNotification = Notification.Name("firstLaunchPermissionLadderDidFinish")

    static var hasCompletedLadder: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static var shouldRunLadder: Bool {
        !hasCompletedLadder
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
    #endif
}

enum FirstLaunchPermissionOutcome: Equatable {
    /// Mic denied / skipped — stay off camera & location prompts.
    case goToLiveWithoutMonitoring
    /// Mic OK, camera denied — Live + start monitoring.
    case goToLiveAndStartMonitoring
    /// Mic + camera OK — remain on Video; location requested after preview configure.
    case stayOnVideo
}

@MainActor
enum FirstLaunchPermissionCoordinator {
    /// Runs once per install. Only system-prompts undetermined permissions in order.
    static func run(
        shouldShowMicIntro: Bool,
        presentMicIntro: () async -> Bool
    ) async -> FirstLaunchPermissionOutcome {
        defer {
            FirstLaunchPermissionStore.markCompleted()
            NotificationCenter.default.post(
                name: FirstLaunchPermissionStore.ladderDidFinishNotification,
                object: nil
            )
        }

        // Already fully set up (reinstall / returning) — nothing to prompt.
        if MediaPermissions.isMicrophoneAuthorized, MediaPermissions.isCameraAuthorized {
            AppTelemetry.logProductEvent(
                "permission_ladder_finished",
                parameters: ["outcome": "already_authorized"]
            )
            return .stayOnVideo
        }

        // Microphone first.
        if MediaPermissions.isMicrophoneDenied {
            AppTelemetry.logProductEvent(
                "permission_ladder_finished",
                parameters: ["outcome": "mic_denied_existing"]
            )
            return .goToLiveWithoutMonitoring
        }

        if MediaPermissions.isMicrophoneUndetermined {
            if shouldShowMicIntro {
                let wantsPrompt = await presentMicIntro()
                guard wantsPrompt else {
                    AppTelemetry.logProductEvent(
                        "permission_ladder_finished",
                        parameters: ["outcome": "mic_intro_dismissed"]
                    )
                    return .goToLiveWithoutMonitoring
                }
            }
            let granted = await MediaPermissions.requestMicrophone()
            AppTelemetry.logProductEvent(
                "permission_ladder_mic",
                parameters: ["granted": granted ? "true" : "false"]
            )
            guard granted else {
                AppTelemetry.logProductEvent(
                    "permission_denied",
                    parameters: ["type": "microphone", "source": "ladder"]
                )
                return .goToLiveWithoutMonitoring
            }
        }

        // Camera second (only after mic granted).
        if MediaPermissions.isCameraDenied {
            AppTelemetry.logProductEvent(
                "permission_ladder_finished",
                parameters: ["outcome": "camera_denied_existing"]
            )
            return .goToLiveAndStartMonitoring
        }

        if MediaPermissions.isCameraUndetermined {
            let granted = await MediaPermissions.requestCamera()
            AppTelemetry.logProductEvent(
                "permission_ladder_camera",
                parameters: ["granted": granted ? "true" : "false"]
            )
            guard granted else {
                AppTelemetry.logProductEvent(
                    "permission_denied",
                    parameters: ["type": "camera", "source": "ladder"]
                )
                return .goToLiveAndStartMonitoring
            }
        }

        AppTelemetry.logProductEvent(
            "permission_ladder_finished",
            parameters: ["outcome": "stay_on_video"]
        )
        return .stayOnVideo
    }
}
