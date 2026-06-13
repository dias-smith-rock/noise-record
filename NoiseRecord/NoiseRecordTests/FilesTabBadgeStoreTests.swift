import XCTest
@testable import NoiseRecord

final class FilesTabBadgeStoreTests: XCTestCase {
    private let pendingKey = "files.tabBadgePending"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
        super.tearDown()
    }

    func testMarkPendingAndClear() {
        XCTAssertFalse(FilesTabBadgeStore.isPending)
        FilesTabBadgeStore.markPending()
        XCTAssertTrue(FilesTabBadgeStore.isPending)
        FilesTabBadgeStore.clear()
        XCTAssertFalse(FilesTabBadgeStore.isPending)
    }
}
