import XCTest
@testable import NoiseRecord

final class DurationFormattingTests: XCTestCase {
    func testHMSFormatsUnderOneHour() {
        XCTAssertEqual(DurationFormatting.hms(from: 457), "07:37")
    }

    func testHMSFormatsOverOneHour() {
        XCTAssertEqual(DurationFormatting.hms(from: 5177), "01:26:17")
    }

    func testHMSFormatsUnderOneMinute() {
        XCTAssertEqual(DurationFormatting.hms(from: 37), "00:37")
    }

    func testHMSFormatsZero() {
        XCTAssertEqual(DurationFormatting.hms(from: 0), "00:00")
    }

    func testHMSClampsNegativeToZero() {
        XCTAssertEqual(DurationFormatting.hms(from: -5), "00:00")
    }
}
