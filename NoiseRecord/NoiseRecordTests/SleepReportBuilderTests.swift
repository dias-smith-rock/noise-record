import XCTest
@testable import NoiseRecord

final class SleepReportBuilderTests: XCTestCase {
    func testQuietNightSummary() {
        let summary = SleepReportBuilder.buildSummary(
            overallLeq: 32,
            noiseFloor: 30,
            anomalies: []
        )
        XCTAssertTrue(summary.contains("32"))
    }

    func testAnomalySummaryIncludesPeakAndImpact() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 1
        components.hour = 3
        components.minute = 14
        let calendar = Calendar.current
        let timestamp = calendar.date(from: components)!

        let summary = SleepReportBuilder.buildSummary(
            overallLeq: 32,
            noiseFloor: 30,
            anomalies: [
                SleepAnomalyCandidate(timestamp: timestamp, peakDB: 65, durationSeconds: 4),
            ],
            calendar: calendar
        )

        XCTAssertTrue(summary.contains("32"))
        XCTAssertTrue(summary.contains("65"))
    }
}
