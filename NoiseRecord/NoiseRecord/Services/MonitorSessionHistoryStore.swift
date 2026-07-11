import Foundation

struct StoredMonitorSessionSnapshot: Codable, Equatable {
    let endedAt: Date
    let duration: TimeInterval
    let maxDB: Float
    let averageDB: Float
}

/// Persists the previous manual monitoring session for end-sheet comparison.
nonisolated enum MonitorSessionHistoryStore {
    private static let lastSessionKey = "monitor.lastSessionSnapshot"

    static var lastSession: StoredMonitorSessionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: lastSessionKey) else { return nil }
        return try? JSONDecoder().decode(StoredMonitorSessionSnapshot.self, from: data)
    }

    static func save(_ summary: MonitorSessionSummary) {
        let snapshot = StoredMonitorSessionSnapshot(
            endedAt: summary.endedAt,
            duration: summary.duration,
            maxDB: summary.maxDB,
            averageDB: summary.averageDB
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: lastSessionKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: lastSessionKey)
    }
    #endif
}
