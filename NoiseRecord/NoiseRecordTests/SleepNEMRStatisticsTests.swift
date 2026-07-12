import XCTest
@testable import NoiseRecord

final class SleepNEMRStatisticsTests: XCTestCase {
    private func makeSession(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date?,
        overallLeq: Float = 57.8,
        noiseFloorDB: Float = 42.1,
        peakDB: Float = 73.2
    ) -> SleepForensicPDFExporter.SleepNoiseSessionSnapshot {
        SleepForensicPDFExporter.SleepNoiseSessionSnapshot(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            overallLeq: overallLeq,
            noiseFloorDB: noiseFloorDB,
            peakDB: peakDB,
            anomalyCount: 0,
            grade: "C",
            weightingMode: WeightingType.a.rawValue,
            isHighSensitivitySession: false,
            startTemperatureCelsius: nil,
            startHumidityPercent: nil,
            endTemperatureCelsius: nil,
            endHumidityPercent: nil,
            startLatitude: nil,
            startLongitude: nil,
            endLatitude: nil,
            endLongitude: nil
        )
    }

    private func makeSample(at date: Date, db: Float) -> SleepForensicPDFExporter.SampleSnapshot {
        SleepForensicPDFExporter.SampleSnapshot(
            timestamp: date,
            dbCurrent: db,
            dbMax: db + 1,
            leq: db
        )
    }

    func testReportNumberFormat() {
        let id = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let date = ISO8601DateFormatter().date(from: "2026-07-04T12:00:00Z")!
        let number = SleepNEMRStatistics.reportNumber(for: id, monitoringDate: date)
        XCTAssertTrue(number.hasPrefix("NMR-2026-07-04-"))
        XCTAssertTrue(number.contains("A1B"))
    }

    func testHourlyResultsSingleBucketForShortSession() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = start.addingTimeInterval(1800)
        let session = makeSession(startedAt: start, endedAt: end)
        let samples = [
            makeSample(at: start.addingTimeInterval(60), db: 50),
            makeSample(at: start.addingTimeInterval(120), db: 58),
            makeSample(at: start.addingTimeInterval(300), db: 55),
        ]

        let rows = SleepNEMRStatistics.hourlyResults(session: session, samples: samples, localLimit: 55)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].pointLabel, "P1")
        XCTAssertEqual(rows[0].compliance, .exceed)
        XCTAssertGreaterThan(rows[0].leq, 55)
    }

    func testPeakAnalysisCountsEventsAboveThreshold() {
        let session = makeSession(startedAt: Date(), endedAt: Date().addingTimeInterval(3600))
        let incidents = [
            SleepForensicPDFExporter.IncidentRow(
                timestamp: Date(),
                peakDB: 73.2,
                durationSeconds: 2,
                classification: "Impact",
                recordingSessionID: nil
            ),
            SleepForensicPDFExporter.IncidentRow(
                timestamp: Date().addingTimeInterval(60),
                peakDB: 68,
                durationSeconds: 1,
                classification: "Transient",
                recordingSessionID: nil
            ),
        ]

        let analysis = SleepNEMRStatistics.peakAnalysis(
            session: session,
            anomalies: incidents,
            localLimit: 55
        )
        XCTAssertEqual(analysis.exceedCount, 1)
        XCTAssertEqual(analysis.highestLmax, 73.2, accuracy: 0.01)
        XCTAssertEqual(analysis.compliance, .nonCompliant)
    }

    func testPercentile90() {
        let values: [Float] = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        let l90 = SleepNEMRStatistics.percentile90(values)
        XCTAssertEqual(l90, 90, accuracy: 0.01)
    }

    func testBackgroundCorrectionNoteWhenDeltaGreaterThanTen() {
        let start = Date()
        let session = makeSession(startedAt: start, endedAt: start.addingTimeInterval(3600))
        let rows = [
            SleepNEMRStatistics.HourlyResultRow(
                pointLabel: "P1",
                timeRange: "10:00 PM – 11:00 PM",
                leq: 57.8,
                lmax: 73.2,
                l90: 42.1,
                localLimit: 55,
                epaLDNSuggestion: "≤ 55",
                compliance: .exceed
            ),
        ]
        let peak = SleepNEMRStatistics.PeakAnalysisRow(
            pointLabel: "P1",
            exceedCount: 1,
            exceedTimestamps: [start],
            highestLmax: 73.2,
            peakThreshold: 70,
            compliance: .nonCompliant
        )

        let conclusion = SleepNEMRStatistics.buildConclusion(
            hourlyRows: rows,
            peakRow: peak,
            session: session
        )

        XCTAssertTrue(conclusion.backgroundCorrectionNote.contains("No background correction is required"))
        XCTAssertTrue(conclusion.anyHourlyExceedance)
        XCTAssertTrue(conclusion.anyPeakExceedance)
    }
}
