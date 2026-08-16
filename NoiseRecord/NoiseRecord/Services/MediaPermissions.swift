import AVFoundation
import Foundation

/// Microphone + camera permission helpers for the staged first-launch ladder.
enum MediaPermissions {
    static var isMicrophoneAuthorized: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    static var isMicrophoneUndetermined: Bool {
        AVAudioApplication.shared.recordPermission == .undetermined
    }

    static var isMicrophoneDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }

    static var cameraAuthorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static var isCameraAuthorized: Bool {
        cameraAuthorizationStatus == .authorized
    }

    static var isCameraUndetermined: Bool {
        cameraAuthorizationStatus == .notDetermined
    }

    static var isCameraDenied: Bool {
        switch cameraAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    static func requestMicrophone() async -> Bool {
        await AudioSessionManager.requestPermission()
    }

    static func requestCamera() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Requests when undetermined; returns false when denied/restricted (caller should open Settings).
    @discardableResult
    static func ensureMicrophoneAuthorized() async -> Bool {
        if isMicrophoneAuthorized { return true }
        if isMicrophoneDenied { return false }
        return await requestMicrophone()
    }

    @discardableResult
    static func ensureCameraAuthorized() async -> Bool {
        if isCameraAuthorized { return true }
        if isCameraDenied { return false }
        return await requestCamera()
    }
}
