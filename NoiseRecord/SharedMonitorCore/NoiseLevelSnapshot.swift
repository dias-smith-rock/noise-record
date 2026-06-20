import Foundation

struct NoiseLevelSnapshot: Sendable {
    let currentDB: Float
    let maxDB: Float
    let minDB: Float
    let averageDB: Float
    let leq: Float
    let weighting: WeightingType
    let timestamp: Date
}
