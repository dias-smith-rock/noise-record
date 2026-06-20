import AVFoundation
import Foundation

enum WatchAudioSessionError: LocalizedError {
    case permissionDenied
    case configurationFailed(String)
    case activationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            WatchL10n.micPermissionDenied
        case .configurationFailed(let message):
            message
        case .activationFailed:
            WatchL10n.audioActivationFailed
        }
    }
}

struct WatchAudioSessionManager {
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func configureForMeasurement() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [])
            try session.setActive(true, options: [])
        } catch {
            throw WatchAudioSessionError.configurationFailed(error.localizedDescription)
        }
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
