import Foundation

/// Tracks when to show the App Store rating prompt.
nonisolated enum AppReviewStore {
    enum CoreFeatureKind: String, CaseIterable {
        case monitoring
        case evidenceSaved
        case sleepReport
        case fullscreenLED
    }

    static let shouldPresentPromptNotification = Notification.Name("AppReviewStore.shouldPresentPrompt")
    static let shouldReevaluatePromptNotification = Notification.Name("AppReviewStore.shouldReevaluatePrompt")
    static let minimumMonitoringSeconds: TimeInterval = 60

    private static let hasShownReviewPromptKey = "appReview.hasShownPrompt"
    private static let legacyHasShownReviewPromptKey = "appReview.hasShownFirstFilePrompt"
    private static let hasUsedCoreFeatureKey = "appReview.hasUsedCoreFeature"
    private static let cumulativeMonitoringSecondsKey = "appReview.cumulativeMonitoringSeconds"
    private static let coreFeaturePrefix = "appReview.coreFeature."

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard
    private static var _isFullscreenLEDBusy = false
#if DEBUG
    private static var debugPromptArmed = false

    /// DEBUG 下重复弹出评分引导；单元测试运行时自动关闭。
    private static var allowsRepeatedPromptInDebug: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }
#endif

    static var isFullscreenLEDBusy: Bool {
        get { lock.withLock { _isFullscreenLEDBusy } }
        set { lock.withLock { _isFullscreenLEDBusy = newValue } }
    }

    static var hasShownReviewPrompt: Bool {
        get {
            if defaults.bool(forKey: hasShownReviewPromptKey) {
                return true
            }
            if defaults.bool(forKey: legacyHasShownReviewPromptKey) {
                return true
            }
            return false
        }
        set { defaults.set(newValue, forKey: hasShownReviewPromptKey) }
    }

    static var hasUsedCoreFeature: Bool {
        defaults.bool(forKey: hasUsedCoreFeatureKey)
    }

    static var cumulativeMonitoringSeconds: TimeInterval {
        defaults.double(forKey: cumulativeMonitoringSecondsKey)
    }

    static func configure(defaults: UserDefaults) {
        lock.withLock {
            self.defaults = defaults
        }
    }

    static func resetForTesting() {
        lock.withLock {
            _isFullscreenLEDBusy = false
#if DEBUG
            debugPromptArmed = false
#endif
        }
        for key in [
            hasShownReviewPromptKey,
            legacyHasShownReviewPromptKey,
            hasUsedCoreFeatureKey,
            cumulativeMonitoringSecondsKey,
        ] + CoreFeatureKind.allCases.map({ coreFeaturePrefix + $0.rawValue }) {
            defaults.removeObject(forKey: key)
        }
    }

    static func recordMonitoringElapsed(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
#if DEBUG
        if allowsRepeatedPromptInDebug {
            let total = cumulativeMonitoringSeconds + seconds
            defaults.set(total, forKey: cumulativeMonitoringSecondsKey)
            guard total >= minimumMonitoringSeconds else { return }
            noteCoreFeatureUsed(.monitoring)
            defaults.set(0, forKey: cumulativeMonitoringSecondsKey)
            return
        }
#endif
        guard !hasCoreFeatureRecorded(.monitoring) else { return }

        let total = cumulativeMonitoringSeconds + seconds
        defaults.set(total, forKey: cumulativeMonitoringSecondsKey)
        guard total >= minimumMonitoringSeconds else { return }
        noteCoreFeatureUsed(.monitoring)
    }

    static func noteCoreFeatureUsed(_ kind: CoreFeatureKind) {
        let key = coreFeaturePrefix + kind.rawValue
#if DEBUG
        if allowsRepeatedPromptInDebug {
            defaults.set(true, forKey: key)
            defaults.set(true, forKey: hasUsedCoreFeatureKey)
            lock.withLock { debugPromptArmed = true }
            return
        }
#endif
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        defaults.set(true, forKey: hasUsedCoreFeatureKey)
    }

    static func evaluatePromptIfEligible(isBusy: Bool) {
        guard hasUsedCoreFeature, !isBusy else { return }
#if DEBUG
        if allowsRepeatedPromptInDebug {
            guard lock.withLock({ debugPromptArmed }) else { return }
            lock.withLock { debugPromptArmed = false }
        } else {
            guard !hasShownReviewPrompt else { return }
            hasShownReviewPrompt = true
        }
#else
        guard !hasShownReviewPrompt else { return }
        hasShownReviewPrompt = true
#endif
        NotificationCenter.default.post(name: shouldPresentPromptNotification, object: nil)
    }

    private static func hasCoreFeatureRecorded(_ kind: CoreFeatureKind) -> Bool {
        defaults.bool(forKey: coreFeaturePrefix + kind.rawValue)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
