import Foundation

struct SessionStopSummary {
    let duration: TimeInterval
    let fileSizeBytes: Int64
    let autoSavedSegmentCount: Int
    let deferredEvent: RecordingFinishedEvent
}
