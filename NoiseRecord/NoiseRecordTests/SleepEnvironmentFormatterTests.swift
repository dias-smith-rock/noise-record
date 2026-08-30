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
        let copy = SleepNEMRCopy(primaryLanguage: .zhHant)
        XCTAssertEqual(
            SleepEnvironmentFormatter.pdfNEMRLine(start: nil, copy: copy),
            "未記錄 (Not recorded)"
        )
        let englishOnly = SleepNEMRCopy(primaryLanguage: .en)
        XCTAssertEqual(
            SleepEnvironmentFormatter.pdfNEMRLine(start: nil, copy: englishOnly),
            "Not recorded"
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
