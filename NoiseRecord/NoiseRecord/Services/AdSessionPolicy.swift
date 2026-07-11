import Foundation

/// Session-scoped ad retry / fail reporting policy to avoid fail-event spam.
nonisolated enum AdSessionPolicy {
    private static let lock = NSLock()
    private static var sessionFailCounts: [String: Int] = [:]
    private static var sessionRetryCounts: [String: Int] = [:]

    static func resetSessionCounters() {
        lock.withLock {
            sessionFailCounts.removeAll()
            sessionRetryCounts.removeAll()
        }
    }

    static var allowsAdsToday: Bool {
        LaunchExperienceStore.allowsAdsOnFirstInstallDay
    }

    static func shouldAttemptAdLoadOrShow() -> Bool {
        allowsAdsToday
    }

    /// Returns whether a commercial `ad_fail` analytics event should be emitted.
    static func shouldReportCommercialFail(channel: String, step: String) -> Bool {
        let key = "\(channel)|\(step)"
        return lock.withLock {
            let count = sessionFailCounts[key, default: 0]
            guard count < AdMobConfig.maxCommercialFailReportsPerSession else { return false }
            sessionFailCounts[key] = count + 1
            return true
        }
    }

    static func retryDelayMs(for retryCount: Int) -> Int {
        let base = AdMobConfig.presentationRetryDelayMs
        let multiplier = max(1, 1 << retryCount)
        return min(base * multiplier, AdMobConfig.maxPresentationRetryDelayMs)
    }

    static func canSchedulePresentationRetry(channel: String, retryCount: Int) -> Bool {
        lock.withLock {
            guard retryCount < AdMobConfig.maxPresentationRetries else { return false }
            let attempts = sessionRetryCounts[channel, default: 0]
            guard attempts < AdMobConfig.maxPresentationRetries else { return false }
            sessionRetryCounts[channel] = attempts + 1
            return true
        }
    }

    static func notePresentationSucceeded(channel: String) {
        lock.withLock {
            sessionRetryCounts[channel] = 0
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
