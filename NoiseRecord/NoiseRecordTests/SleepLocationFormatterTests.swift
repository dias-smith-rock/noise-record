import XCTest
@testable import NoiseRecord

final class SleepLocationFormatterTests: XCTestCase {
    func testFormattedCoordinatesUsesHemisphereLabels() {
        let text = SleepLocationFormatter.formattedCoordinates(latitude: 37.7749, longitude: -122.4194)
        XCTAssertEqual(text, "37.7749° N, 122.4194° W")
    }

    func testPDFEnglishSummaryFormatsStartCoordinates() {
        let start = SleepLocationSnapshot(latitude: 22.3193, longitude: 114.1694)
        let summary = SleepLocationFormatter.pdfEnglishSummary(start: start)
        XCTAssertEqual(summary, "22.3193° N, 114.1694° E (session start)")
    }

    func testPDFEnglishSummaryIncludesAbbreviatedPlaceName() {
        let start = SleepLocationSnapshot(latitude: 37.7749, longitude: -122.4194)
        let summary = SleepLocationFormatter.pdfEnglishSummary(
            start: start,
            startPlaceName: "San Francisco, CA"
        )
        XCTAssertEqual(
            summary,
            "37.7749° N, 122.4194° W — San Francisco, CA (session start)"
        )
    }

    func testPDFNEMRLineUsesResolvedSummary() {
        XCTAssertEqual(
            SleepLocationFormatter.pdfNEMRLine(
                fromResolvedSummary: "37.7749° N, 122.4194° W — San Francisco, CA (session start)"
            ),
            "37.7749° N, 122.4194° W — San Francisco, CA (session start) / 37.7749° N, 122.4194° W — San Francisco, CA (session start)"
        )
    }

    func testPDFEnglishSummaryReturnsNilWhenMissing() {
        XCTAssertNil(SleepLocationFormatter.pdfEnglishSummary(start: nil))
    }

    func testPDFNEMRLineUsesFallbackWhenMissing() {
        XCTAssertEqual(
            SleepLocationFormatter.pdfNEMRLine(start: nil),
            "Not recorded / 未记录"
        )
    }
}
