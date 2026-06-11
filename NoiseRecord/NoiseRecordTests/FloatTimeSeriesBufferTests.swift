import XCTest
@testable import NoiseRecord

final class FloatTimeSeriesBufferTests: XCTestCase {
    func testAppendAndSnapshotOrder() {
        var buffer = FloatTimeSeriesBuffer(capacity: 4)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        var snapshot: [Float] = []
        buffer.copyChronological(into: &snapshot)
        XCTAssertEqual(snapshot, [1, 2, 3])
    }

    func testWrapAroundSnapshot() {
        var buffer = FloatTimeSeriesBuffer(capacity: 3)
        [1, 2, 3, 4].forEach { buffer.append(Float($0)) }

        var snapshot: [Float] = []
        buffer.copyChronological(into: &snapshot)
        XCTAssertEqual(snapshot, [2, 3, 4])
    }

    func testFFTSampleRingWindow() {
        var ring = FFTSampleRing(capacity: 4)
        let samples: [Float] = [1, 2, 3, 4, 5]
        samples.withUnsafeBufferPointer { ring.write($0.baseAddress!, count: samples.count) }

        XCTAssertTrue(ring.isReadyForAnalysis)
        var scratch = [Float](repeating: 0, count: 4)
        ring.copyLatestWindow(into: &scratch)
        XCTAssertEqual(scratch, [2, 3, 4, 5])
    }
}
