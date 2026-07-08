import XCTest
@testable import NoiseRecord

final class LaunchExperienceStoreTests: XCTestCase {
    override func tearDown() {
        LaunchExperienceStore.resetForTesting()
        super.tearDown()
    }

    func testFirstColdLaunchDefersPaywall() {
        LaunchExperienceStore.resetForTesting()
        XCTAssertEqual(LaunchExperienceStore.recordColdLaunch(), 1)
        XCTAssertTrue(LaunchExperienceStore.shouldDeferLaunchPaywallOnColdStart)
    }

    func testSecondColdLaunchShowsPaywall() {
        LaunchExperienceStore.resetForTesting()
        _ = LaunchExperienceStore.recordColdLaunch()
        XCTAssertEqual(LaunchExperienceStore.recordColdLaunch(), 2)
        XCTAssertFalse(LaunchExperienceStore.shouldDeferLaunchPaywallOnColdStart)
    }

    func testMarkLaunchPaywallShownStopsDeferral() {
        LaunchExperienceStore.resetForTesting()
        _ = LaunchExperienceStore.recordColdLaunch()
        LaunchExperienceStore.markLaunchPaywallShown()
        XCTAssertFalse(LaunchExperienceStore.shouldDeferLaunchPaywallOnColdStart)
    }
}
