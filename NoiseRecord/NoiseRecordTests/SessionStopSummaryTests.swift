import XCTest
@testable import NoiseRecord

final class SessionStopSummaryTests: XCTestCase {
    func testFileSizeFormatting() {
        XCTAssertFalse(DurationFormatting.fileSize(from: 2_400_000).isEmpty)
    }

    func testSessionStopMessageFormatsSegmentCount() {
        let message = L10n.dashboardStopPromptSessionMessage(
            duration: "01:11",
            fileSize: "2.4 MB",
            segmentCount: 3
        )
        XCTAssertTrue(message.contains("01:11"))
        XCTAssertTrue(message.contains("3"))
    }
}
