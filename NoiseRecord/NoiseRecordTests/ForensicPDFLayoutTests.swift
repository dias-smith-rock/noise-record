import XCTest
@testable import NoiseRecord

final class ForensicPDFLayoutTests: XCTestCase {
    func testFormattedDurationShowsSubMinuteWithoutRoundingUp() {
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(30), "30s")
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(59.9), "59s")
    }

    func testFormattedDurationTruncatesFractionalSeconds() {
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(59.6), "59s")
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(125.9), "2m 05s")
    }

    func testFormattedDurationDoesNotRoundHoursOrMinutes() {
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(3_661), "1h 01m 01s")
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(3_599.9), "59m 59s")
    }

    func testFormattedDurationZero() {
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(0), "0s")
        XCTAssertEqual(ForensicPDFLayout.formattedDuration(-5), "0s")
    }
}
