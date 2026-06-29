import Foundation

/// 免费层用量追踪（视频每日次数等）。
final class FreemiumUsageStore: @unchecked Sendable {
    static let shared = FreemiumUsageStore()

    static let freeVideoDailyLimit = 1
    static let freeVideoMaxDuration: TimeInterval = 10

    private let defaults: UserDefaults
    private let dayKey = "freemium.videoUsageDay"
    private let countKey = "freemium.videoUsageCount"
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

    func recordVideoSessionStarted() {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDayLocked()
        let next = defaults.integer(forKey: countKey) + 1
        defaults.set(next, forKey: countKey)
    }

    #if DEBUG
    func resetVideoUsageForTesting() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: dayKey)
        defaults.removeObject(forKey: countKey)
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
