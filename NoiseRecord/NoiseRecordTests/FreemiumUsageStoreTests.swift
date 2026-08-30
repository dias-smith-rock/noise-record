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

    func testRecordingIsAlwaysAllowed() {
        XCTAssertTrue(store.canStartVideoRecording(isPremium: false))
        store.recordVideoSessionStarted()
        XCTAssertTrue(store.canStartVideoRecording(isPremium: false))
        XCTAssertTrue(store.canStartVideoRecording(isPremium: true))
    }

    func testAllowedDurationIsUnlimited() {
        XCTAssertEqual(
            store.allowedVideoSaveDuration(isPremium: false),
            .greatestFiniteMagnitude
        )
        XCTAssertEqual(
            store.allowedVideoSaveDuration(isPremium: true),
            .greatestFiniteMagnitude
        )
    }
}
