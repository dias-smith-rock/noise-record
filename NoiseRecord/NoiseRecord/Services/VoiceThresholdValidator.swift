import Foundation

enum VoiceThresholdValidator {
    static func normalized(high: Float, low: Float) -> (high: Float, low: Float) {
        guard high <= low else { return (high, low) }
        let adjustedLow = max(20, high - 1)
        if adjustedLow < high {
            return (high, adjustedLow)
        }
        return (min(90, low + 1), low)
    }
}
