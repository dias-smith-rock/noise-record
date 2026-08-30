import XCTest
@testable import NoiseRecord

final class SleepPDFPreviewAccessStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SleepPDFPreviewAccessStore.resetForTesting()
    }

    override func tearDown() {
        SleepPDFPreviewAccessStore.resetForTesting()
        super.tearDown()
    }

    /// Blur gating is retired; helpers remain for migration/tests.
    func testBlurHelpersStillToggleForLegacyCompatibility() {
        XCTAssertFalse(SleepPDFPreviewAccessStore.shouldBlurPreview(isPremium: false))
        SleepPDFPreviewAccessStore.markGlobalFreePreviewConsumed()
        XCTAssertTrue(SleepPDFPreviewAccessStore.shouldBlurPreview(isPremium: false))
        XCTAssertFalse(SleepPDFPreviewAccessStore.shouldBlurPreview(isPremium: true))
    }
}
