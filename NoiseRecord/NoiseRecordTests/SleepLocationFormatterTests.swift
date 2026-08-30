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
        let copy = SleepNEMRCopy(primaryLanguage: .en)
        XCTAssertEqual(
            SleepLocationFormatter.pdfNEMRLine(
                fromResolvedSummary: "37.7749° N, 122.4194° W — San Francisco, CA (session start)",
                copy: copy
            ),
            "37.7749° N, 122.4194° W — San Francisco, CA (session start)"
        )
    }

    func testPDFEnglishSummaryReturnsNilWhenMissing() {
        XCTAssertNil(SleepLocationFormatter.pdfEnglishSummary(start: nil))
    }

    func testPDFNEMRLineUsesFallbackWhenMissing() {
        let copy = SleepNEMRCopy(primaryLanguage: .zhHant)
        XCTAssertEqual(
            SleepLocationFormatter.pdfNEMRLine(start: nil, copy: copy),
            "未記錄 (Not recorded)"
        )
        let englishOnly = SleepNEMRCopy(primaryLanguage: .en)
        XCTAssertEqual(
            SleepLocationFormatter.pdfNEMRLine(start: nil, copy: englishOnly),
            "Not recorded"
        )
    }
}
