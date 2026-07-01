import XCTest
@testable import NoiseRecord

final class NoiseTimelineAlignmentTests: XCTestCase {
    func testPeakMapsToTimestampNotIndexWhenDurationExceedsTimelineSpan() {
        let peakTime = 40.0
        let playbackDuration = 60.0
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [
                VideoNoiseSample(time: 0, decibel: 40),
                VideoNoiseSample(time: peakTime, decibel: 90),
                VideoNoiseSample(time: 55, decibel: 42),
            ],
            source: .offline,
            normalized: true
        )

        let peakFraction = peakTime / playbackDuration
        let indexBasedFraction = 1.0 / 2.0

        XCTAssertNotEqual(peakFraction, indexBasedFraction, accuracy: 0.01)
        XCTAssertEqual(timeline.decibel(at: peakTime), Optional(90))
        XCTAssertLessThan(timeline.decibel(at: peakTime - 5) ?? 0, 90)
        XCTAssertLessThan(timeline.decibel(at: peakTime + 5) ?? 0, 90)
    }

    func testDecibelStrictReturnsNilOutsideSampleSpan() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [
                VideoNoiseSample(time: 1, decibel: 40),
                VideoNoiseSample(time: 5, decibel: 80),
            ]
        )

        XCTAssertNil(timeline.decibelStrict(at: 0.5))
        XCTAssertEqual(timeline.decibelStrict(at: 3), Optional(60))
        XCTAssertNil(timeline.decibelStrict(at: 6))
        XCTAssertEqual(timeline.decibel(at: 0.5), Optional(40))
    }

    func testNormalizedTimelineScalesTimestampsToFileDuration() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [
                VideoNoiseSample(time: 0, decibel: 40),
                VideoNoiseSample(time: 50, decibel: 80),
            ],
            source: .live,
            normalized: false
        )

        let normalized = timeline.normalized(to: 60, source: .live)
        XCTAssertEqual(normalized?.samples.last?.time ?? 0, 60, accuracy: 0.001)
        XCTAssertEqual(normalized?.normalized, true)
        XCTAssertEqual(normalized?.isValidForPlaybackAlignment, true)
    }

    func testLegacyTimelineIsNotValidForPlaybackAlignment() throws {
        let legacyJSON = """
        {
            "version": 1,
            "weighting": "dBA",
            "samples": [
                { "time": 0.0, "decibel": 40.0 },
                { "time": 1.0, "decibel": 55.0 }
            ]
        }
        """.data(using: .utf8)!

        let timeline = try JSONDecoder().decode(VideoNoiseTimeline.self, from: legacyJSON)
        XCTAssertEqual(timeline.version, 1)
        XCTAssertEqual(timeline.isValidForPlaybackAlignment, false)
    }

    func testCurrentTimelineVersionIsTwo() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [VideoNoiseSample(time: 0, decibel: 40)],
            source: .offline,
            normalized: true
        )

        XCTAssertEqual(timeline.version, VideoNoiseTimeline.currentVersion)
        XCTAssertEqual(timeline.isValidForPlaybackAlignment, true)
    }
}
