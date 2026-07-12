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

    func testFirstPreviewIsNotBlurredForFreeUser() {
        XCTAssertFalse(SleepPDFPreviewAccessStore.shouldBlurPreview(isPremium: false))
    }

    func testPreviewBlursAfterGlobalFreePreviewConsumed() {
        SleepPDFPreviewAccessStore.markGlobalFreePreviewConsumed()
        XCTAssertTrue(SleepPDFPreviewAccessStore.shouldBlurPreview(isPremium: false))
    }

    func testPremiumUserNeverBlursEvenAfterMark() {
        SleepPDFPreviewAccessStore.markGlobalFreePreviewConsumed()
        XCTAssertFalse(SleepPDFPreviewAccessStore.shouldBlurPreview(isPremium: true))
    }
}
