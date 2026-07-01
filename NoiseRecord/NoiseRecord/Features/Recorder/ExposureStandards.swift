import Foundation

/// OSHA-style exposure dose defaults for display and dose calculation.
enum ExposureStandards {
    static let criterionDurationHours: Double = 8
    static let criterionDurationSeconds: TimeInterval = criterionDurationHours * 3600
    static let criterionLevelDB: Float = 85
    static let thresholdLevelDB: Float = 80
    static let exchangeRateDB: Float = 3
    static let timeWeightingSeconds: Double = 1.0
    static let peakWeighting: WeightingType = .c
}
