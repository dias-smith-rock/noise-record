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

    static func configureForMeasurement(backgroundEnabled: Bool = false) throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
        if backgroundEnabled {
            options.insert(.mixWithOthers)
        }
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: options)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioSessionError.configurationFailed(error.localizedDescription)
        }
    }
}
