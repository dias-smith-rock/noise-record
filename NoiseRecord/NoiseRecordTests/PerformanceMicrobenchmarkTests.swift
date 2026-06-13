import XCTest
@testable import NoiseRecord

final class PerformanceMicrobenchmarkTests: XCTestCase {
    func testSPLCalculatorThroughput() {
        var samples = [Float](repeating: 0.01, count: 1024)
        measure {
            for _ in 0..<100 {
                samples.withUnsafeBufferPointer { ptr in
                    _ = SPLCalculator.spl(
                        from: ptr.baseAddress!,
                        frameLength: samples.count,
                        calibrationOffset: 115
                    )
                }
            }
        }
    }

    func testVideoNoiseTimelineLookup() {
        let timeline = VideoNoiseTimeline(
            weighting: "dBA",
            samples: (0..<600).map { VideoNoiseSample(time: Double($0) * 0.1, decibel: Float($0)) }
        )
        measure {
            for step in 0..<600 {
                _ = timeline.decibel(at: Double(step) * 0.1 + 0.05)
            }
        }
    }
}
