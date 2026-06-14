import Foundation

/// Tracks when to show the App Store rating prompt.
nonisolated enum AppReviewStore {
    static let shouldPresentPromptNotification = Notification.Name("AppReviewStore.shouldPresentPrompt")

    private static let hasShownReviewPromptKey = "appReview.hasShownFirstFilePrompt"

    static var hasShownReviewPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: hasShownReviewPromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasShownReviewPromptKey) }
    }

    /// Call after a successful evidence file save. Shows the prompt once, on the first save after install.
    static func noteEvidenceFileSaved() {
        guard !hasShownReviewPrompt else { return }
        hasShownReviewPrompt = true
        NotificationCenter.default.post(name: shouldPresentPromptNotification, object: nil)
    }
}
