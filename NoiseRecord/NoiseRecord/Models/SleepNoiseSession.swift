import Foundation
import SwiftData

enum SleepNoiseSessionStatus: String, Sendable {
    case active
    case completed
    case aborted
}

@Model
final class SleepNoiseSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var status: String
    var noiseFloorDB: Float
    var overallLeq: Float
    var peakDB: Float
    var anomalyCount: Int
    var grade: String
    var reportSummary: String?
    var isReportRead: Bool
    var weightingMode: String

    @Relationship(deleteRule: .cascade, inverse: \SleepAnomalyEvent.sleepSession)
    var anomalies: [SleepAnomalyEvent]

    init(startedAt: Date = Date()) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = nil
        self.status = SleepNoiseSessionStatus.active.rawValue
        self.noiseFloorDB = 0
        self.overallLeq = 0
        self.peakDB = 0
        self.anomalyCount = 0
        self.grade = SilenceGrade.a.rawValue
        self.reportSummary = nil
        self.isReportRead = false
        self.weightingMode = ""
        self.anomalies = []
    }

    var isHighSensitivitySession: Bool {
        weightingMode == "highSensitivity"
    }

    var sessionStatus: SleepNoiseSessionStatus {
        get { SleepNoiseSessionStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }

    var silenceGrade: SilenceGrade {
        SilenceGrade(rawValue: grade) ?? SilenceGrade.from(leq: overallLeq)
    }
}
