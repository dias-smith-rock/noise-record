import Foundation

/// Freemium media rules: in-app save is free; long preview / export / share / clean PDF
/// require VIP, with one complimentary use of each per calendar week.
@MainActor
enum MediaEntitlementGate {
    /// Free users may fully preview clips at or under this duration without consuming weekly credit.
    static let freeFullPreviewMaxDuration: TimeInterval = 3

    static var isPremium: Bool {
        SubscriptionManager.shared.isPremiumUser
    }

    static var canExportOrShare: Bool {
        isPremium
            || WeeklyFreemiumAllowanceStore.shared.hasRemaining(kind: .export)
            || WeeklyFreemiumAllowanceStore.shared.hasRemaining(kind: .share)
    }

    static func allowsFullPreview(duration: TimeInterval, isPremium: Bool? = nil) -> Bool {
        let premium = isPremium ?? Self.isPremium
        guard !premium else { return true }
        guard duration.isFinite, duration > 0 else { return true }
        return duration <= freeFullPreviewMaxDuration + 0.05
    }

    /// `nil` means unrestricted playback; otherwise pause/clamp at this time.
    /// Pass `weeklyPreviewUnlocked` after a successful `tryUnlockFullPreview`.
    static func previewPlaybackLimit(
        duration: TimeInterval,
        isPremium: Bool? = nil,
        weeklyPreviewUnlocked: Bool = false
    ) -> TimeInterval? {
        if weeklyPreviewUnlocked { return nil }
        return allowsFullPreview(duration: duration, isPremium: isPremium)
            ? nil
            : freeFullPreviewMaxDuration
    }

    static func clampSeekTime(
        _ time: TimeInterval,
        duration: TimeInterval,
        isPremium: Bool? = nil,
        weeklyPreviewUnlocked: Bool = false
    ) -> TimeInterval {
        let upper = previewPlaybackLimit(
            duration: duration,
            isPremium: isPremium,
            weeklyPreviewUnlocked: weeklyPreviewUnlocked
        ) ?? max(duration, 0)
        return min(max(time, 0), upper)
    }

    /// Consumes weekly full-preview credit when available. Does not present paywall.
    @discardableResult
    static func consumeWeeklyFullPreviewIfAvailable(triggerFeature: String) -> Bool {
        if isPremium { return true }
        guard WeeklyFreemiumAllowanceStore.shared.consume(kind: .fullPreview) else { return false }
        AppTelemetry.logProductEvent(
            "weekly_allowance_consumed",
            parameters: [
                "kind": WeeklyFreemiumAllowanceStore.Kind.fullPreview.rawValue,
                "trigger_feature": triggerFeature,
            ]
        )
        return true
    }

    /// Call when playback reaches the free 3s wall while the full asset is loaded.
    /// Consumes weekly full-preview credit if available; otherwise presents VIP paywall via shared presenter.
    @discardableResult
    static func tryUnlockFullPreview(triggerFeature: String) -> Bool {
        if consumeWeeklyFullPreviewIfAvailable(triggerFeature: triggerFeature) {
            return true
        }
        PaywallPresenter.shared.present(
            context: .mediaPreviewLimit,
            triggerFeature: triggerFeature
        )
        return false
    }

    @discardableResult
    static func requireExportAccess(triggerFeature: String) -> Bool {
        if isPremium { return true }
        if WeeklyFreemiumAllowanceStore.shared.consume(kind: .export) {
            AppTelemetry.logProductEvent(
                "weekly_allowance_consumed",
                parameters: [
                    "kind": WeeklyFreemiumAllowanceStore.Kind.export.rawValue,
                    "trigger_feature": triggerFeature,
                ]
            )
            return true
        }
        PaywallPresenter.shared.present(
            context: .mediaExport,
            triggerFeature: triggerFeature
        )
        return false
    }

    @discardableResult
    static func requireShareAccess(triggerFeature: String) -> Bool {
        if isPremium { return true }
        if WeeklyFreemiumAllowanceStore.shared.consume(kind: .share) {
            AppTelemetry.logProductEvent(
                "weekly_allowance_consumed",
                parameters: [
                    "kind": WeeklyFreemiumAllowanceStore.Kind.share.rawValue,
                    "trigger_feature": triggerFeature,
                ]
            )
            return true
        }
        PaywallPresenter.shared.present(
            context: .mediaExport,
            triggerFeature: triggerFeature
        )
        return false
    }

    /// Clean (no-watermark) sleep PDF export / share.
    @discardableResult
    static func requireCleanPDFExportAccess(triggerFeature: String) -> Bool {
        if isPremium { return true }
        if WeeklyFreemiumAllowanceStore.shared.consume(kind: .cleanPDFExport) {
            AppTelemetry.logProductEvent(
                "weekly_allowance_consumed",
                parameters: [
                    "kind": WeeklyFreemiumAllowanceStore.Kind.cleanPDFExport.rawValue,
                    "trigger_feature": triggerFeature,
                ]
            )
            return true
        }
        PaywallPresenter.shared.present(
            context: .sleepExport,
            triggerFeature: triggerFeature
        )
        return false
    }

    /// Whether in-app PDF preview should show the watermark overlay.
    static var shouldWatermarkSleepPDFPreview: Bool {
        !isPremium
    }
}
