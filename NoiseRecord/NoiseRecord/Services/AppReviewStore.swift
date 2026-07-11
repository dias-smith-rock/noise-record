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
    static let minimumFilesForReviewPrompt = 2

    private static let hasShownReviewPromptKey = "appReview.hasShownPrompt"
    private static let legacyHasShownReviewPromptKey = "appReview.hasShownFirstFilePrompt"
    private static let hasUsedCoreFeatureKey = "appReview.hasUsedCoreFeature"
    private static let cumulativeMonitoringSecondsKey = "appReview.cumulativeMonitoringSeconds"
    private static let coreFeaturePrefix = "appReview.coreFeature."
    private static var isPromptPresentationPending = false
    private static var latestFilesCount = 0

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
        isPromptPresentationPending = false
        latestFilesCount = 0
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

    static func updateLatestFilesCount(_ count: Int) {
        latestFilesCount = max(0, count)
    }

    static func evaluatePromptIfEligible(isBusy: Bool) {
        evaluatePromptIfEligible(isBusy: isBusy, filesCount: latestFilesCount)
    }

    static func evaluatePromptIfEligible(isBusy: Bool, filesCount: Int) {
        guard hasUsedCoreFeature, !isBusy else { return }
        guard filesCount >= minimumFilesForReviewPrompt else { return }
        guard !hasShownReviewPrompt, !isPromptPresentationPending else { return }
#if DEBUG
        if allowsRepeatedPromptInDebug {
            guard lock.withLock({ debugPromptArmed }) else { return }
            lock.withLock { debugPromptArmed = false }
        }
#else
        // Release 仅在 Alert 真正展示后再标记已弹出。
#endif
        isPromptPresentationPending = true
        NotificationCenter.default.post(name: shouldPresentPromptNotification, object: nil)
    }

    /// Alert 已展示后调用，避免 Sheet 抢焦点导致“闪一下”仍被记为已弹出。
    static func markReviewPromptPresented() {
        isPromptPresentationPending = false
        hasShownReviewPrompt = true
    }

    /// Sheet 或其他 UI 抢占了 Alert 时撤销 pending，便于稍后重新评估。
    static func cancelPendingReviewPrompt() {
        isPromptPresentationPending = false
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
