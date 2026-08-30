import Foundation

/// Per-user weekly free Pro-action allowances (one of each kind per calendar week).
final class WeeklyFreemiumAllowanceStore: @unchecked Sendable {
    static let shared = WeeklyFreemiumAllowanceStore()

    enum Kind: String, CaseIterable, Sendable {
        case fullPreview
        case export
        case share
        case cleanPDFExport
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let weekKeyPrefix = "freemium.weekly.week."
    private let usedKeyPrefix = "freemium.weekly.used."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func remaining(kind: Kind, now: Date = Date()) -> Int {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewWeekLocked(kind: kind, now: now)
        return defaults.bool(forKey: usedKey(kind)) ? 0 : 1
    }

    func hasRemaining(kind: Kind, now: Date = Date()) -> Bool {
        remaining(kind: kind, now: now) > 0
    }

    /// Consumes one weekly allowance. Returns `false` if already used this week.
    @discardableResult
    func consume(kind: Kind, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewWeekLocked(kind: kind, now: now)
        let key = usedKey(kind)
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        return true
    }

    #if DEBUG
    func resetAllForTesting() {
        lock.lock()
        defer { lock.unlock() }
        for kind in Kind.allCases {
            defaults.removeObject(forKey: weekKey(kind))
            defaults.removeObject(forKey: usedKey(kind))
        }
    }
    #endif

    private func usedKey(_ kind: Kind) -> String { usedKeyPrefix + kind.rawValue }
    private func weekKey(_ kind: Kind) -> String { weekKeyPrefix + kind.rawValue }

    private func resetIfNewWeekLocked(kind: Kind, now: Date) {
        let current = Self.weekToken(from: now)
        let key = weekKey(kind)
        let stored = defaults.string(forKey: key)
        guard stored != current else { return }
        defaults.set(current, forKey: key)
        defaults.set(false, forKey: usedKey(kind))
    }

    static func weekToken(from date: Date, calendar: Calendar = .current) -> String {
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }
}
