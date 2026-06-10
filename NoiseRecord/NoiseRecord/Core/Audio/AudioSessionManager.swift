import AVFoundation

enum AudioSessionError: LocalizedError {
    case permissionDenied
    case configurationFailed(String)
    case activationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            L10n.errorMicPermissionDenied
        case .configurationFailed(let message):
            L10n.errorAudioConfigurationFailed(message)
        case .activationFailed:
            L10n.errorAudioActivationFailed
        }
    }

    static func wrap(_ error: Error) -> AudioSessionError {
        let nsError = error as NSError
        if nsError.domain == NSOSStatusErrorDomain,
           nsError.code == AVAudioSession.ErrorCode.cannotStartPlaying.rawValue {
            return .activationFailed
        }
        return .configurationFailed(error.localizedDescription)
    }
}

struct AudioSessionManager {
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Strict measurement session: bypasses system AGC, noise suppression, and echo cancellation.
    /// Never use `.voiceChat` / `.videoChat` categories here.
    static func configureForMeasurement(backgroundEnabled: Bool = false) throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [
            .allowBluetooth,
            .defaultToSpeaker,
        ]
        if backgroundEnabled {
            // Required so mic capture can continue after the app enters the background
            // when UIBackgroundModes includes "audio".
            options.insert(.mixWithOthers)
            options.insert(.allowBluetoothA2DP)
        }
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: options)
            try session.overrideOutputAudioPort(.none)
        } catch {
            throw AudioSessionError.configurationFailed(error.localizedDescription)
        }
    }

    /// Routes playback to the loudspeaker. Keeps `playAndRecord` when the mic engine is active.
    static func configureForPlayback(
        coexistingWithMonitoring: Bool,
        backgroundEnabled: Bool = false
    ) throws {
        let session = AVAudioSession.sharedInstance()
        do {
            if coexistingWithMonitoring {
                try session.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
                )
            } else {
                // `defaultToSpeaker` is only valid with `playAndRecord`.
                try session.setCategory(.playback, mode: .default)
            }
            try session.setActive(true)
            // Non-fatal: simulator or some routes may reject speaker override.
            try? session.overrideOutputAudioPort(.speaker)
        } catch {
            throw AudioSessionError.configurationFailed(error.localizedDescription)
        }
    }

    static func restoreMeasurementIfMonitoring(_ isMonitoring: Bool, backgroundEnabled: Bool = false) {
        guard isMonitoring else { return }
        try? BackgroundAudioSession.activateForMeasurement(backgroundEnabled: backgroundEnabled)
    }
}
