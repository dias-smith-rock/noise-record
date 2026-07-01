import XCTest
@testable import NoiseRecord

final class RecordingWaveformAnalyzerTests: XCTestCase {
    func testThumbnailCacheReturnsDataForVideoSidecar() throws {
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumbnail-video-\(UUID().uuidString).mp4")
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: [
                VideoNoiseSample(time: 0, decibel: 42),
                VideoNoiseSample(time: 1, decibel: 58),
                VideoNoiseSample(time: 2, decibel: 51),
            ],
            source: .live,
            normalized: true
        )

        defer {
            try? FileManager.default.removeItem(at: videoURL)
            VideoNoiseTimelineStore.remove(for: videoURL)
            WaveformThumbnailCache.invalidate(for: videoURL)
        }

        FileManager.default.createFile(atPath: videoURL.path, contents: Data())
        try VideoNoiseTimelineStore.save(timeline, for: videoURL)

        let thumbnail = WaveformThumbnailCache.thumbnail(for: videoURL)

        XCTAssertNotNil(thumbnail)
        XCTAssertEqual(thumbnail?.timeline.samples.count, 3)
        XCTAssertGreaterThan(thumbnail?.playbackDuration ?? 0, 0)
    }

    func testLoadCachedTimelineForThumbnailReadsVideoSidecar() throws {
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cached-video-\(UUID().uuidString).mp4")
        let timeline = VideoNoiseTimeline(
            weighting: "dBZ",
            samples: [VideoNoiseSample(time: 0.5, decibel: 63.5)]
        )

        defer {
            try? FileManager.default.removeItem(at: videoURL)
            VideoNoiseTimelineStore.remove(for: videoURL)
        }

        FileManager.default.createFile(atPath: videoURL.path, contents: Data())
        try VideoNoiseTimelineStore.save(timeline, for: videoURL)

        let loaded = RecordingWaveformAnalyzer.loadCachedTimelineForThumbnail(for: videoURL)

        XCTAssertEqual(loaded?.samples.count, 1)
        XCTAssertEqual(loaded?.samples.first?.decibel ?? -1, 63.5, accuracy: 0.001)
    }
}
