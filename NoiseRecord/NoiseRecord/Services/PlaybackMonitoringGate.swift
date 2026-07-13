import Foundation

enum PlaybackMonitoringInterruptionKind: Equatable, Sendable {
    case none
    case standard
    case sleep
}

enum PlaybackMediaKind: String, Sendable {
    case audio
    case video
}

@MainActor
struct PlaybackMonitoringGate {
    let engine: NoiseMonitorEngine
    let sleepCoordinator: SleepNoiseMonitorCoordinator
    let audioStateManager: AudioStateManager
    let environmentSnapshot: () -> SleepEnvironmentSnapshot

    nonisolated static func interruptionKind(
        isEngineMonitoring: Bool,
        isSleepMonitoring: Bool
    ) -> PlaybackMonitoringInterruptionKind {
        if isSleepMonitoring { return .sleep }
        if isEngineMonitoring { return .standard }
        return .none
    }

    func interruptionKind() -> PlaybackMonitoringInterruptionKind {
        Self.interruptionKind(
            isEngineMonitoring: engine.isMonitoring,
            isSleepMonitoring: sleepCoordinator.isSleepMonitoring
        )
    }

    @discardableResult
    func prepareForPlayback(mediaKind: PlaybackMediaKind) async throws -> Bool {
        let kind = interruptionKind()
        let endedSleepSession: Bool
        switch kind {
        case .none, .standard:
            try audioStateManager.prepareAndStartPlayback()
            endedSleepSession = false
        case .sleep:
            let snapshot = environmentSnapshot()
            sleepCoordinator.noteEnvironmentSnapshot(snapshot)
            await sleepCoordinator.endSession(
                environment: snapshot,
                presentReportImmediately: false,
                persistPendingReportID: false
            )
            audioStateManager.noteMonitoringStopped()
            try audioStateManager.prepareAndStartPlayback()
            endedSleepSession = true
        }

        AppTelemetry.logProductEvent(
            "files_playback_confirm_continue",
            parameters: [
                "mode": telemetryMode(for: kind),
                "kind": mediaKind.rawValue,
            ]
        )
        return endedSleepSession
    }

    func logConfirmationShown(mediaKind: PlaybackMediaKind) {
        let kind = interruptionKind()
        AppTelemetry.logProductEvent(
            "files_playback_confirm_shown",
            parameters: [
                "mode": telemetryMode(for: kind),
                "kind": mediaKind.rawValue,
            ]
        )
    }

    func logConfirmationCancelled(mediaKind: PlaybackMediaKind) {
        let kind = interruptionKind()
        AppTelemetry.logProductEvent(
            "files_playback_confirm_cancel",
            parameters: [
                "mode": telemetryMode(for: kind),
                "kind": mediaKind.rawValue,
            ]
        )
    }

    private func telemetryMode(for kind: PlaybackMonitoringInterruptionKind) -> String {
        switch kind {
        case .none: "none"
        case .standard: "standard"
        case .sleep: "sleep"
        }
    }
}
