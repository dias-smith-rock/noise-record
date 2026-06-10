import AVFoundation
import Foundation

/// Keeps the measurement audio session alive while the app is backgrounded.
enum BackgroundAudioSession {
    /// - Parameter skipSessionActivation: When `AVAudioEngine` is already running, the session
    ///   stays active. Re-calling `setActive(true)` during background/foreground transitions often
    ///   fails with "Session activation failed" (561015905) even though capture still works.
    static func activateForMeasurement(
        backgroundEnabled: Bool,
        skipSessionActivation: Bool = false
    ) throws {
        try AudioSessionManager.configureForMeasurement(backgroundEnabled: backgroundEnabled)

        let session = AVAudioSession.sharedInstance()
        try session.setPreferredSampleRate(44_100)
        try session.setPreferredIOBufferDuration(0.005)

        guard !skipSessionActivation else { return }
        try session.setActive(true)
    }

    static func interruptionType(in notification: Notification) -> AVAudioSession.InterruptionType? {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else {
            return nil
        }
        return AVAudioSession.InterruptionType(rawValue: raw)
    }

    static func shouldResumeAfterInterruption(_ notification: Notification) -> Bool {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else {
            return false
        }
        return AVAudioSession.InterruptionOptions(rawValue: raw).contains(.shouldResume)
    }
}
