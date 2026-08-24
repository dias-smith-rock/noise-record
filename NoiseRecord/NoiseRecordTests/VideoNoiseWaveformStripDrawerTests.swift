import XCTest
@testable import NoiseRecord

final class VideoNoiseWaveformStripDrawerTests: XCTestCase {
    func testDecibelStrictInterpolatesBetweenSamples() {
        let samples = [
            VideoNoiseSample(time: 0, decibel: 40),
            VideoNoiseSample(time: 10, decibel: 60),
        ]

        let midpoint = VideoNoiseWaveformStripDrawer.decibelStrict(in: samples, at: 5)
        XCTAssertEqual(midpoint ?? 0, 50, accuracy: 0.001)
    }

    func testDecibelStrictReturnsNilOutsideSampleSpan() {
        let samples = [
            VideoNoiseSample(time: 1, decibel: 40),
            VideoNoiseSample(time: 2, decibel: 50),
        ]

        XCTAssertNil(VideoNoiseWaveformStripDrawer.decibelStrict(in: samples, at: 0.5))
        XCTAssertNil(VideoNoiseWaveformStripDrawer.decibelStrict(in: samples, at: 2.5))
    }

    func testRollingSamplesUsesRecentWindowUpToCurrentTime() {
        let samples = (0..<150).map {
            VideoNoiseSample(time: Double($0), decibel: Float($0))
        }

        let window = VideoNoiseWaveformStripDrawer.rollingSamples(from: samples, upTo: 149)
        XCTAssertEqual(window.count, VideoNoiseWaveformStripDrawer.rollingSampleCapacity)
        XCTAssertEqual(window.first?.time, 30)
        XCTAssertEqual(window.last?.time, 149)
    }

    func testRollingSamplesExcludesFutureSamples() {
        let samples = [
            VideoNoiseSample(time: 0, decibel: 40),
            VideoNoiseSample(time: 5, decibel: 50),
            VideoNoiseSample(time: 10, decibel: 60),
        ]

        let window = VideoNoiseWaveformStripDrawer.rollingSamples(from: samples, upTo: 5)
        XCTAssertEqual(window.count, 2)
        XCTAssertEqual(window.last?.time, 5)
    }
}
