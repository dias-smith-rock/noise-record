import XCTest
@testable import NoiseRecord

final class PaywallFrequencyStoreTests: XCTestCase {
    override func tearDown() {
        PaywallFrequencyStore.resetForTesting()
        super.tearDown()
    }

    func testAutomaticContextOnlyLaunch() {
        XCTAssertTrue(PaywallFrequencyStore.isAutomaticContext(.launch))
        XCTAssertFalse(PaywallFrequencyStore.isAutomaticContext(.settings))
    }

    func testSuppressesAfterTwoClosesWithinSevenDays() {
        PaywallFrequencyStore.recordDismiss(context: .launch)
        PaywallFrequencyStore.recordDismiss(context: .launch)
        XCTAssertTrue(PaywallFrequencyStore.shouldSuppressAutomaticPaywall)
    }

    func testFeatureContextDoesNotCountTowardCap() {
        PaywallFrequencyStore.recordDismiss(context: .settings)
        PaywallFrequencyStore.recordDismiss(context: .sleepExport)
        XCTAssertFalse(PaywallFrequencyStore.shouldSuppressAutomaticPaywall)
    }
}

final class LaunchExperienceStoreFirstInstallTests: XCTestCase {
    override func tearDown() {
        LaunchExperienceStore.resetForTesting()
        super.tearDown()
    }

    func testFirstInstallDayBlocksAds() {
        LaunchExperienceStore.resetForTesting()
        _ = LaunchExperienceStore.recordColdLaunch()
        XCTAssertTrue(LaunchExperienceStore.isFirstInstallDay)
        XCTAssertFalse(LaunchExperienceStore.allowsAdsOnFirstInstallDay)
    }

    func testSecondDayAllowsAds() {
        LaunchExperienceStore.resetForTesting()
        LaunchExperienceStore.recordFirstInstallIfNeeded()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(
            yesterday.timeIntervalSince1970,
            forKey: "launch.firstInstallDate"
        )
        XCTAssertFalse(LaunchExperienceStore.isFirstInstallDay)
        XCTAssertTrue(LaunchExperienceStore.allowsAdsOnFirstInstallDay)
    }
}

final class AdSessionPolicyTests: XCTestCase {
    override func tearDown() {
        Task { @MainActor in
            AdSessionPolicy.resetSessionCounters()
        }
        super.tearDown()
    }

    func testCommercialFailReportingIsCappedPerSession() {
        AdSessionPolicy.resetSessionCounters()
        XCTAssertTrue(AdSessionPolicy.shouldReportCommercialFail(channel: "cold", step: "load_failed"))
        XCTAssertTrue(AdSessionPolicy.shouldReportCommercialFail(channel: "cold", step: "load_failed"))
        XCTAssertFalse(AdSessionPolicy.shouldReportCommercialFail(channel: "cold", step: "load_failed"))
    }

    func testRetryDelayUsesExponentialBackoff() {
        XCTAssertEqual(AdSessionPolicy.retryDelayMs(for: 0), 300)
        XCTAssertEqual(AdSessionPolicy.retryDelayMs(for: 1), 600)
    }

    func testFullscreenAdCooldownBlocksWithinTwoMinutes() {
        AdSessionPolicy.resetFullscreenCooldownForTesting()
        XCTAssertTrue(AdSessionPolicy.shouldPresentFullscreenAd())

        let presentedAt = Date(timeIntervalSince1970: 1_000_000)
        AdSessionPolicy.notePresentationSucceeded(channel: "cold", at: presentedAt)

        XCTAssertFalse(
            AdSessionPolicy.shouldPresentFullscreenAd(
                now: presentedAt.addingTimeInterval(60)
            )
        )
        XCTAssertTrue(
            AdSessionPolicy.shouldPresentFullscreenAd(
                now: presentedAt.addingTimeInterval(120)
            )
        )
        XCTAssertEqual(
            AdSessionPolicy.remainingFullscreenCooldownSeconds(
                now: presentedAt.addingTimeInterval(30)
            ),
            90,
            accuracy: 0.001
        )
    }

    func testFullscreenAdCooldownIsSharedAcrossChannels() {
        AdSessionPolicy.resetFullscreenCooldownForTesting()
        AdSessionPolicy.notePresentationSucceeded(channel: "cold", at: Date(timeIntervalSince1970: 2_000_000))
        XCTAssertFalse(
            AdSessionPolicy.shouldPresentFullscreenAd(
                now: Date(timeIntervalSince1970: 2_000_000 + 30)
            )
        )
    }
}

final class AppOnboardingStoreTests: XCTestCase {
    override func tearDown() {
        AppOnboardingStore.resetForTesting()
        super.tearDown()
    }

    func testMeasureTaskCompletionRequestsReportOnce() {
        AppOnboardingStore.resetForTesting()
        XCTAssertFalse(AppOnboardingStore.noteMonitoringElapsed(5, isMonitoring: true))
        XCTAssertTrue(AppOnboardingStore.noteMonitoringElapsed(10, isMonitoring: true))
        XCTAssertEqual(AppOnboardingStore.currentStep, .visitFiles)
        XCTAssertFalse(AppOnboardingStore.noteMonitoringElapsed(12, isMonitoring: true))
    }
}
