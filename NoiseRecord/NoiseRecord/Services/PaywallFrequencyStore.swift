import Foundation

/// Tracks Paywall dismissals to cap automatic (launch) presentations.
nonisolated enum PaywallFrequencyStore {
    private static let closeTimestampsKey = "paywall.closeTimestamps"
    private static let maxAutomaticCloses = 2
    private static let rollingWindow: TimeInterval = 7 * 24 * 60 * 60

    static func isAutomaticContext(_ context: PaywallContext) -> Bool {
        context == .launch
    }

    static var shouldSuppressAutomaticPaywall: Bool {
        recentCloseCount(within: rollingWindow) >= maxAutomaticCloses
    }

    static func recordDismiss(context: PaywallContext) {
        guard isAutomaticContext(context) else { return }
        var timestamps = loadCloseTimestamps()
        timestamps.append(Date())
        timestamps = timestamps.filter { Date().timeIntervalSince($0) <= rollingWindow }
        saveCloseTimestamps(timestamps)
    }

    static func recentCloseCount(within interval: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-interval)
        return loadCloseTimestamps().filter { $0 >= cutoff }.count
    }

    private static func loadCloseTimestamps() -> [Date] {
        guard let raw = UserDefaults.standard.array(forKey: closeTimestampsKey) as? [Double] else {
            return []
        }
        return raw.map(Date.init(timeIntervalSince1970:))
    }

    private static func saveCloseTimestamps(_ timestamps: [Date]) {
        UserDefaults.standard.set(
            timestamps.map(\.timeIntervalSince1970),
            forKey: closeTimestampsKey
        )
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: closeTimestampsKey)
    }
    #endif
}
