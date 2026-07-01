import Foundation

extension RecordingState {
    var localizedStatusText: String {
        switch self {
        case .idle: L10n.recordingSessionMonitoring
        case .recording: L10n.recordingAuto
        }
    }
}
