import XCTest
@testable import NoiseRecord

final class FreemiumUsageStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: FreemiumUsageStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "FreemiumUsageStoreTests")!
        defaults.removePersistentDomain(forName: "FreemiumUsageStoreTests")
        store = FreemiumUsageStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "FreemiumUsageStoreTests")
        super.tearDown()
    }

    func testPremiumBypassesDailyVideoLimit() {
        XCTAssertTrue(store.canStartVideoRecording(isPremium: true))
        store.recordVideoSessionStarted()
        XCTAssertTrue(store.canStartVideoRecording(isPremium: true))
    }

    func testFreeUserCanRecordOncePerDay() {
        XCTAssertTrue(store.canStartVideoRecording(isPremium: false))
        store.recordVideoSessionStarted()
        XCTAssertFalse(store.canStartVideoRecording(isPremium: false))
        XCTAssertEqual(store.remainingVideoRecordingsToday(isPremium: false), 0)
    }

    func testRemainingCountBeforeUse() {
        XCTAssertEqual(store.remainingVideoRecordingsToday(isPremium: false), 1)
    }

    func testFirstClipGetsLongerAllowance() {
        XCTAssertEqual(
            store.allowedVideoSaveDuration(isPremium: false),
            FreemiumUsageStore.freeVideoFirstClipMaxDuration
        )
        store.markFirstClipBonusConsumedIfNeeded()
        XCTAssertEqual(
            store.allowedVideoSaveDuration(isPremium: false),
            FreemiumUsageStore.freeVideoStandardMaxDuration
        )
        XCTAssertTrue(store.hasUsedFirstClipBonus())
    }

    func testPremiumAllowedDurationIsUnlimited() {
        XCTAssertEqual(
            store.allowedVideoSaveDuration(isPremium: true),
            .greatestFiniteMagnitude
        )
    }

    #if DEBUG
    func testResetClearsUsage() {
        store.recordVideoSessionStarted()
        store.markFirstClipBonusConsumedIfNeeded()
        XCTAssertFalse(store.canStartVideoRecording(isPremium: false))
        store.resetVideoUsageForTesting()
        XCTAssertTrue(store.canStartVideoRecording(isPremium: false))
        XCTAssertFalse(store.hasUsedFirstClipBonus())
        XCTAssertEqual(
            store.allowedVideoSaveDuration(isPremium: false),
            FreemiumUsageStore.freeVideoFirstClipMaxDuration
        )
    }
    #endif
}
