import Foundation
import SwiftData

@Model
final class MeasurementSample {
    var id: UUID
    var timestamp: Date
    var dbCurrent: Float
    var dbMax: Float
    var dbMin: Float
    var dbAvg: Float
    var leq: Float
    var weighting: String
    var noiseType: String?

    init(
        timestamp: Date,
        dbCurrent: Float,
        dbMax: Float,
        dbMin: Float,
        dbAvg: Float,
        leq: Float,
        weighting: String,
        noiseType: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.dbCurrent = dbCurrent
        self.dbMax = dbMax
        self.dbMin = dbMin
        self.dbAvg = dbAvg
        self.leq = leq
        self.weighting = weighting
        self.noiseType = noiseType
    }
}
