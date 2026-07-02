import XCTest
@testable import NoiseRecord

final class SleepNoiseAnalyzerTests: XCTestCase {
    func testNoiseFloorUsesTenthPercentile() {
        let values: [Float] = [30, 32, 34, 36, 38, 40, 42, 44, 46, 80]
        XCTAssertEqual(SleepNoiseAnalyzer.noiseFloor(from: values), 30)
    }

    func testDetectsAnomalyAboveFloorDelta() {
        let base = Date()
        let samples: [(timestamp: Date, leq: Float, peak: Float)] = [
            (base, 32, 32),
            (base.addingTimeInterval(30), 33, 33),
            (base.addingTimeInterval(60), 50, 50),
            (base.addingTimeInterval(90), 51, 51),
            (base.addingTimeInterval(120), 52, 52),
            (base.addingTimeInterval(150), 34, 34),
        ]

        let floor = SleepNoiseAnalyzer.noiseFloor(from: samples.map(\.leq))
        let anomalies = SleepNoiseAnalyzer.detectAnomalies(
            samples: samples,
            noiseFloor: floor,
            referenceDB: 55
        )

        XCTAssertEqual(anomalies.count, 1)
        XCTAssertEqual(anomalies[0].peakDB, 52, accuracy: 0.1)
    }

    func testShortSpikeIsIgnored() {
        let base = Date()
        let samples: [(timestamp: Date, leq: Float, peak: Float)] = [
            (base, 32, 32),
            (base.addingTimeInterval(1), 70, 70),
            (base.addingTimeInterval(2), 33, 33),
        ]

        let floor = SleepNoiseAnalyzer.noiseFloor(from: samples.map(\.leq))
        let anomalies = SleepNoiseAnalyzer.detectAnomalies(
            samples: samples,
            noiseFloor: floor,
            referenceDB: 55
        )
        XCTAssertTrue(anomalies.isEmpty)
    }

    func testDeepSleepHintForEarlyMorning() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 1
        components.hour = 3
        components.minute = 14
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        XCTAssertEqual(SleepNoiseAnalyzer.sleepImpactHint(for: date, calendar: calendar), .deepSleep)
    }

    func testDynamicVADThresholds() {
        let thresholds = SleepNoiseAnalyzer.dynamicVADThresholds(noiseFloor: 32)
        XCTAssertEqual(thresholds.high, 50)
        XCTAssertEqual(thresholds.low, 43)
    }

    func testHighSensitivitySkipsFixedReferenceThreshold() {
        let base = Date()
        let samples: [(timestamp: Date, leq: Float, peak: Float)] = [
            (base, 48, 48),
            (base.addingTimeInterval(30), 48, 48),
            (base.addingTimeInterval(60), 56, 56),
            (base.addingTimeInterval(90), 57, 57),
            (base.addingTimeInterval(120), 58, 58),
            (base.addingTimeInterval(150), 49, 49),
        ]

        let floor = SleepNoiseAnalyzer.noiseFloor(from: samples.map(\.leq))
        XCTAssertEqual(floor, 48)

        let standardAnomalies = SleepNoiseAnalyzer.detectAnomalies(
            samples: samples,
            noiseFloor: floor,
            referenceDB: 55,
            isHighSensitivity: false
        )
        let highSensitivityAnomalies = SleepNoiseAnalyzer.detectAnomalies(
            samples: samples,
            noiseFloor: floor,
            referenceDB: 55,
            isHighSensitivity: true
        )

        XCTAssertEqual(standardAnomalies.count, 1)
        XCTAssertEqual(highSensitivityAnomalies.count, 1)
    }

    func testLiveAnomalyDetectionIncludesOngoingEvent() {
        let base = Date()
        let samples: [(timestamp: Date, leq: Float, peak: Float)] = [
            (base, 48, 48),
            (base.addingTimeInterval(1), 48, 60),
            (base.addingTimeInterval(2), 48, 61),
        ]

        let anomalies = SleepNoiseAnalyzer.detectAnomalies(
            samples: samples,
            noiseFloor: 48,
            referenceDB: 55,
            isHighSensitivity: true,
            referenceTime: base.addingTimeInterval(4),
            includeOngoing: true,
            minimumDuration: SleepNoiseAnalyzer.liveAnomalyMinimumDuration
        )

        XCTAssertEqual(anomalies.count, 1)
    }

    func testLiveNoiseFloorUsesRecentWindow() {
        let stableRecent = Array(repeating: Float(52), count: 10)
        let floor = SleepNoiseAnalyzer.liveNoiseFloor(
            recentLevels: stableRecent,
            persistedLeqSamples: [23, 24, 25]
        )
        XCTAssertEqual(floor ?? 0, 52, accuracy: 0.5)
    }

    func testLiveNoiseFloorIgnoresZeroAndFallsBackToPersisted() {
        XCTAssertNil(
            SleepNoiseAnalyzer.liveNoiseFloor(
                recentLevels: [],
                persistedLeqSamples: []
            )
        )
        let floor = SleepNoiseAnalyzer.liveNoiseFloor(
            recentLevels: [0, 0],
            persistedLeqSamples: [30, 32, 34, 36, 38]
        )
        XCTAssertNotNil(floor)
        XCTAssertEqual(floor ?? 0, 30, accuracy: 1)
    }

    func testLiveNoiseFloorWarmupScenario() {
        let recent = [Float(23)] + Array(repeating: Float(52), count: 9)
        let floor = SleepNoiseAnalyzer.liveNoiseFloor(
            recentLevels: recent,
            persistedLeqSamples: []
        )
        XCTAssertEqual(floor ?? 0, 52, accuracy: 0.5)
    }

    func testMergeReportSamplesPrefersRecentLevelsForShortSession() {
        let recent = Array(repeating: Float(51), count: 12)
        let snapshot: (timestamp: Date, leq: Float, peak: Float) = (Date(), 52, 55)
        let merged = SleepNoiseAnalyzer.mergeReportSamples(
            persisted: [],
            inMemory: [],
            recentLevels: recent,
            recentInterval: 1,
            finalSnapshot: snapshot
        )
        XCTAssertGreaterThanOrEqual(merged.count, 12)
        let result = SleepNoiseAnalyzer.finalize(
            samples: merged,
            referenceDB: 55,
            isHighSensitivity: true
        )
        XCTAssertGreaterThan(result.overallLeq, 45)
        XCTAssertGreaterThan(result.noiseFloor, 45)
    }

    func testMergeReportSamplesUsesPersistedForLongSession() {
        let now = Date()
        var persisted: [(timestamp: Date, leq: Float, peak: Float)] = []
        for index in 0..<8 {
            persisted.append((
                timestamp: now.addingTimeInterval(Double(index) * 30),
                leq: Float(34 + index),
                peak: Float(40 + index)
            ))
        }
        let merged = SleepNoiseAnalyzer.mergeReportSamples(
            persisted: persisted,
            inMemory: persisted,
            recentLevels: Array(repeating: Float(60), count: 20),
            recentInterval: 1,
            finalSnapshot: nil
        )
        XCTAssertEqual(merged.count, persisted.count)
        XCTAssertLessThan(merged.first?.leq ?? 100, 45)
    }
}
