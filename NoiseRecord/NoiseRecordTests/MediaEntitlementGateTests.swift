import XCTest
@testable import NoiseRecord

@MainActor
final class MediaEntitlementGateTests: XCTestCase {
    func testShortClipsAllowFullPreviewForFreeUsers() {
        XCTAssertTrue(MediaEntitlementGate.allowsFullPreview(duration: 2.5, isPremium: false))
        XCTAssertNil(MediaEntitlementGate.previewPlaybackLimit(duration: 2.5, isPremium: false))
    }

    func testLongClipsCapPreviewForFreeUsersUntilWeeklyUnlock() {
        XCTAssertFalse(MediaEntitlementGate.allowsFullPreview(duration: 12, isPremium: false))
        XCTAssertEqual(
            MediaEntitlementGate.previewPlaybackLimit(duration: 12, isPremium: false),
            MediaEntitlementGate.freeFullPreviewMaxDuration
        )
        XCTAssertEqual(
            MediaEntitlementGate.clampSeekTime(9, duration: 12, isPremium: false),
            3
        )
        XCTAssertNil(
            MediaEntitlementGate.previewPlaybackLimit(
                duration: 12,
                isPremium: false,
                weeklyPreviewUnlocked: true
            )
        )
    }

    func testPremiumUsersHaveNoPreviewCap() {
        XCTAssertTrue(MediaEntitlementGate.allowsFullPreview(duration: 120, isPremium: true))
        XCTAssertNil(MediaEntitlementGate.previewPlaybackLimit(duration: 120, isPremium: true))
        XCTAssertEqual(
            MediaEntitlementGate.clampSeekTime(90, duration: 120, isPremium: true),
            90
        )
    }
}

final class WeeklyFreemiumAllowanceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: WeeklyFreemiumAllowanceStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "WeeklyFreemiumAllowanceStoreTests")!
        defaults.removePersistentDomain(forName: "WeeklyFreemiumAllowanceStoreTests")
        store = WeeklyFreemiumAllowanceStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "WeeklyFreemiumAllowanceStoreTests")
        super.tearDown()
    }

    func testEachKindCanBeConsumedOncePerWeek() {
        XCTAssertTrue(store.hasRemaining(kind: .fullPreview))
        XCTAssertTrue(store.consume(kind: .fullPreview))
        XCTAssertFalse(store.hasRemaining(kind: .fullPreview))
        XCTAssertFalse(store.consume(kind: .fullPreview))

        XCTAssertTrue(store.consume(kind: .export))
        XCTAssertTrue(store.consume(kind: .share))
        XCTAssertTrue(store.consume(kind: .cleanPDFExport))
        XCTAssertFalse(store.consume(kind: .export))
    }

    func testWeekTokenStableWithinSameWeek() {
        let date = Date()
        let a = WeeklyFreemiumAllowanceStore.weekToken(from: date)
        let b = WeeklyFreemiumAllowanceStore.weekToken(from: date)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.contains("W"))
    }
}
