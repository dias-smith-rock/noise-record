import Foundation

extension RecordingState {
    var localizedStatusText: String {
        switch self {
        case .idle: L10n.recordingVoiceStandby
        case .recording: L10n.recordingAuto
        case .coolingDown: L10n.recordingTailDelay
        }
    }
}
