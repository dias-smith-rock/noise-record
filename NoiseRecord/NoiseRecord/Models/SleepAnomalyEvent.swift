import Foundation
import SwiftData

enum SleepImpactHint: String, Sendable {
    case deepSleep
    case lightSleep
}

@Model
final class SleepAnomalyEvent {
    var id: UUID
    var timestamp: Date
    var peakDB: Float
    var durationSeconds: Float
    var sleepImpactHint: String?
    var recordingSessionID: UUID?

    var sleepSession: SleepNoiseSession?

    init(
        timestamp: Date,
        peakDB: Float,
        durationSeconds: Float,
        sleepImpactHint: SleepImpactHint? = nil,
        recordingSessionID: UUID? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.peakDB = peakDB
        self.durationSeconds = durationSeconds
        self.sleepImpactHint = sleepImpactHint?.rawValue
        self.recordingSessionID = recordingSessionID
    }

    var impactHint: SleepImpactHint? {
        guard let sleepImpactHint else { return nil }
        return SleepImpactHint(rawValue: sleepImpactHint)
    }
}
