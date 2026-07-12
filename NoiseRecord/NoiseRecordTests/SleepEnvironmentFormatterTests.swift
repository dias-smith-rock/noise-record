import XCTest
@testable import NoiseRecord

final class SleepEnvironmentFormatterTests: XCTestCase {
    func testPDFEnglishSummaryFormatsStartValues() {
        let start = SleepEnvironmentSnapshot(temperatureCelsius: 22, humidityPercent: 65)
        let summary = SleepEnvironmentFormatter.pdfEnglishSummary(start: start)
        XCTAssertEqual(summary, "22°C, 65% RH")
    }

    func testPDFEnglishSummaryReturnsNilWhenMissing() {
        XCTAssertNil(SleepEnvironmentFormatter.pdfEnglishSummary(start: nil))
    }

    func testPDFNEMRLineUsesFallbackWhenMissing() {
        XCTAssertEqual(
            SleepEnvironmentFormatter.pdfNEMRLine(start: nil),
            "Not recorded / 未记录"
        )
    }

    func testAppSummaryClauseReturnsNilWhenMissing() {
        XCTAssertNil(
            SleepEnvironmentFormatter.appSummaryClause(
                temperatureCelsius: nil,
                humidityPercent: nil
            )
        )
    }

    func testAppSummaryClauseIncludesTemperatureAndHumidity() {
        let clause = SleepEnvironmentFormatter.appSummaryClause(
            temperatureCelsius: 21.5,
            humidityPercent: 58
        )
        XCTAssertEqual(clause, "22°C, 58% RH")
    }
}
