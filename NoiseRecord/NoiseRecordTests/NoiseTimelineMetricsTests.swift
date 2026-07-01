import XCTest
@testable import NoiseRecord

final class NoiseTimelineMetricsTests: XCTestCase {
    func testEmptyTimelineUsesFallbackValues() {
        let metrics = NoiseTimelineMetrics.compute(
            from: nil,
            sessionDuration: 2,
            fallbackPeak: 66,
            fallbackAverage: 65
        )

        XCTAssertEqual(metrics.duration, 2, accuracy: 0.001)
        XCTAssertEqual(metrics.peakDB, 66, accuracy: 0.001)
        XCTAssertEqual(metrics.maximumDB, 66, accuracy: 0.001)
        XCTAssertEqual(Double(metrics.laeqDB ?? 0), 65, accuracy: 0.001)
        XCTAssertNil(metrics.timeAveragedDB)
        XCTAssertEqual(metrics.dosePercent, 0, accuracy: 0.001)
    }

    func testLAeqFromConstantSamples() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [
                VideoNoiseSample(time: 0.0, decibel: 60),
                VideoNoiseSample(time: 0.1, decibel: 60),
                VideoNoiseSample(time: 0.2, decibel: 60)
            ]
        )

        let metrics = NoiseTimelineMetrics.compute(
            from: timeline,
            sessionDuration: 0.2,
            fallbackPeak: 0,
            fallbackAverage: 0
        )

        XCTAssertEqual(metrics.laeqDB ?? 0, 60, accuracy: 0.2)
        XCTAssertEqual(metrics.peakDB, 60, accuracy: 0.001)
        XCTAssertEqual(metrics.dosePercent, 0, accuracy: 0.001)
    }

    func testShortRecordingTimeAveragedIsNil() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [VideoNoiseSample(time: 0.0, decibel: 70)]
        )

        let metrics = NoiseTimelineMetrics.compute(
            from: timeline,
            sessionDuration: 1,
            fallbackPeak: 70,
            fallbackAverage: 70
        )

        XCTAssertNil(metrics.timeAveragedDB)
    }

    func testDoseIsZeroBelowThreshold() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [
                VideoNoiseSample(time: 0.0, decibel: 65),
                VideoNoiseSample(time: 0.1, decibel: 65)
            ]
        )

        let metrics = NoiseTimelineMetrics.compute(
            from: timeline,
            sessionDuration: 0.1,
            fallbackPeak: 65,
            fallbackAverage: 65
        )

        XCTAssertEqual(metrics.dosePercent, 0, accuracy: 0.001)
        XCTAssertEqual(metrics.projectedDosePercent, 0, accuracy: 0.001)
    }
}
