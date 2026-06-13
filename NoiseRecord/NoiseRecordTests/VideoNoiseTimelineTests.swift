import XCTest
@testable import NoiseRecord

final class VideoNoiseTimelineTests: XCTestCase {
    func testDecibelInterpolatesBetweenSamples() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [
                VideoNoiseSample(time: 0, decibel: 40),
                VideoNoiseSample(time: 1, decibel: 50),
            ]
        )

        XCTAssertEqual(timeline.decibel(at: 0), Optional(40))
        XCTAssertEqual(timeline.decibel(at: 1), Optional(50))
        XCTAssertEqual(timeline.decibel(at: 0.5), Optional(45))
        XCTAssertEqual(timeline.decibel(at: -1), Optional(40))
        XCTAssertEqual(timeline.decibel(at: 2), Optional(50))
    }

    func testTimelineRoundTripThroughStore() throws {
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("timeline-test.mp4")
        let timeline = VideoNoiseTimeline(
            weighting: "dBZ",
            samples: [VideoNoiseSample(time: 0.2, decibel: 63.5)]
        )

        defer {
            try? FileManager.default.removeItem(at: videoURL)
            VideoNoiseTimelineStore.remove(for: videoURL)
        }

        try VideoNoiseTimelineStore.save(timeline, for: videoURL)
        let loaded = VideoNoiseTimelineStore.load(for: videoURL)

        XCTAssertEqual(loaded?.weighting, "dBZ")
        XCTAssertEqual(loaded?.samples.count, 1)
        XCTAssertEqual(loaded?.samples.first?.time ?? -1, 0.2, accuracy: 0.001)
        XCTAssertEqual(loaded?.samples.first?.decibel ?? -1, 63.5, accuracy: 0.001)
    }
}
