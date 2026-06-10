import AVFoundation

enum AudioSessionError: LocalizedError {
    case permissionDenied
    case configurationFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "麦克风权限被拒绝，请在设置中开启。"
        case .configurationFailed(let message):
            "音频会话配置失败：\(message)"
        }
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
            options.insert(.mixWithOthers)
        }
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: options)
            try session.overrideOutputAudioPort(.none)
            try session.setActive(true)
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
        try? configureForMeasurement(backgroundEnabled: backgroundEnabled)
    }
}
