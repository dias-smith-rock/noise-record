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

    #if DEBUG
    func testResetClearsUsage() {
        store.recordVideoSessionStarted()
        XCTAssertFalse(store.canStartVideoRecording(isPremium: false))
        store.resetVideoUsageForTesting()
        XCTAssertTrue(store.canStartVideoRecording(isPremium: false))
    }
    #endif
}
