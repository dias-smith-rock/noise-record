import Foundation

/// Legacy freemium counters retained for migration/tests. Video daily limits and
/// duration caps are no longer enforced — in-app save is free for everyone.
final class FreemiumUsageStore: @unchecked Sendable {
    static let shared = FreemiumUsageStore()

    /// Kept for older analytics / tests; not used as a product gate.
    static let freeVideoDailyLimit = Int.max
    static let freeVideoFirstClipMaxDuration: TimeInterval = .greatestFiniteMagnitude
    static let freeVideoStandardMaxDuration: TimeInterval = .greatestFiniteMagnitude
    static var freeVideoMaxDuration: TimeInterval { freeVideoStandardMaxDuration }

    private let defaults: UserDefaults
    private let dayKey = "freemium.videoUsageDay"
    private let countKey = "freemium.videoUsageCount"
    private let firstClipBonusUsedKey = "freemium.videoFirstClipBonusUsed"
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func canStartVideoRecording(isPremium: Bool) -> Bool {
        _ = isPremium
        return true
    }

    func remainingVideoRecordingsToday(isPremium: Bool) -> Int {
        _ = isPremium
        return Int.max
    }

    func allowedVideoSaveDuration(isPremium: Bool) -> TimeInterval {
        _ = isPremium
        return .greatestFiniteMagnitude
    }

    func hasUsedFirstClipBonus() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return defaults.bool(forKey: firstClipBonusUsedKey)
    }

    func recordVideoSessionStarted() {
        // No-op: daily quota removed.
    }

    func markFirstClipBonusConsumedIfNeeded() {
        // No-op: first-clip bonus removed with duration caps.
    }

    #if DEBUG
    func resetVideoUsageForTesting() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: dayKey)
        defaults.removeObject(forKey: countKey)
        defaults.removeObject(forKey: firstClipBonusUsedKey)
    }
    #endif
}
