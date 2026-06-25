import Foundation

/// One finalized MP4 segment from a continuous video evidence capture session.
struct VideoSegmentFinishedEvent: Sendable {
    let fileURL: URL
    let segmentIndex: Int
    let segmentGroupID: UUID
    let startedAt: Date
    let endedAt: Date
    let peakDB: Float
    let averageDB: Float
}
