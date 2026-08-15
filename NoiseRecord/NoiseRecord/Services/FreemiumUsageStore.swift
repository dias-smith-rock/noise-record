import Foundation

/// 免费层用量追踪（视频每日次数、首条加长试用等）。
final class FreemiumUsageStore: @unchecked Sendable {
    static let shared = FreemiumUsageStore()

    static let freeVideoDailyLimit = 1
    /// Lifetime first free clip — long enough to feel like shareable proof.
    static let freeVideoFirstClipMaxDuration: TimeInterval = 45
    /// Subsequent free clips.
    static let freeVideoStandardMaxDuration: TimeInterval = 30

    /// Backward-compatible alias for UI that still reads a single constant.
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
        guard !isPremium else { return true }
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDayLocked()
        return defaults.integer(forKey: countKey) < Self.freeVideoDailyLimit
    }

    func remainingVideoRecordingsToday(isPremium: Bool) -> Int {
        guard !isPremium else { return Int.max }
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDayLocked()
        let used = defaults.integer(forKey: countKey)
        return max(0, Self.freeVideoDailyLimit - used)
    }

    /// Max seconds the next free save may keep. Premium is unlimited.
    func allowedVideoSaveDuration(isPremium: Bool) -> TimeInterval {
        guard !isPremium else { return .greatestFiniteMagnitude }
        lock.lock()
        defer { lock.unlock() }
        if defaults.bool(forKey: firstClipBonusUsedKey) {
            return Self.freeVideoStandardMaxDuration
        }
        return Self.freeVideoFirstClipMaxDuration
    }

    func hasUsedFirstClipBonus() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return defaults.bool(forKey: firstClipBonusUsedKey)
    }

    func recordVideoSessionStarted() {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDayLocked()
        let next = defaults.integer(forKey: countKey) + 1
        defaults.set(next, forKey: countKey)
    }

    /// Call after a free clip is successfully saved (including trimmed saves).
    func markFirstClipBonusConsumedIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !defaults.bool(forKey: firstClipBonusUsedKey) else { return }
        defaults.set(true, forKey: firstClipBonusUsedKey)
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

    private func resetIfNewDayLocked() {
        let today = Self.dayString(from: Date())
        let storedDay = defaults.string(forKey: dayKey)
        guard storedDay != today else { return }
        defaults.set(today, forKey: dayKey)
        defaults.set(0, forKey: countKey)
    }

    private static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
