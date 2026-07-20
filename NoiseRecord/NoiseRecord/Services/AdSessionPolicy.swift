import Foundation

/// Session-scoped ad retry / fail reporting policy to avoid fail-event spam.
nonisolated enum AdSessionPolicy {
    private static let lock = NSLock()
    private static var sessionFailCounts: [String: Int] = [:]
    private static var sessionRetryCounts: [String: Int] = [:]
    private static var lastFullscreenPresentationAt: Date?

    static func resetSessionCounters() {
        lock.withLock {
            sessionFailCounts.removeAll()
            sessionRetryCounts.removeAll()
            lastFullscreenPresentationAt = nil
        }
    }

    /// Test helper: clear cooldown without wiping fail/retry counters.
    static func resetFullscreenCooldownForTesting() {
        lock.withLock {
            lastFullscreenPresentationAt = nil
        }
    }

    /// Test helper: seed last presentation time for cooldown checks.
    static func setLastFullscreenPresentationForTesting(_ date: Date?) {
        lock.withLock {
            lastFullscreenPresentationAt = date
        }
    }

    static var allowsAdsToday: Bool {
        LaunchExperienceStore.allowsAdsOnFirstInstallDay
    }

    static func shouldAttemptAdLoadOrShow() -> Bool {
        allowsAdsToday
    }

    /// Shared cooldown for cold app-open and hot interstitial fullscreen ads.
    static func shouldPresentFullscreenAd(
        now: Date = Date(),
        cooldown: TimeInterval = AdMobConfig.fullscreenAdCooldownSeconds
    ) -> Bool {
        lock.withLock {
            guard let last = lastFullscreenPresentationAt else { return true }
            return now.timeIntervalSince(last) >= cooldown
        }
    }

    static func remainingFullscreenCooldownSeconds(now: Date = Date()) -> TimeInterval {
        lock.withLock {
            guard let last = lastFullscreenPresentationAt else { return 0 }
            let elapsed = now.timeIntervalSince(last)
            return max(0, AdMobConfig.fullscreenAdCooldownSeconds - elapsed)
        }
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

    static func notePresentationSucceeded(channel: String, at date: Date = Date()) {
        lock.withLock {
            sessionRetryCounts[channel] = 0
            lastFullscreenPresentationAt = date
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
