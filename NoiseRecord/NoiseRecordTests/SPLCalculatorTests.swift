import XCTest
@testable import NoiseRecord

final class SPLCalculatorTests: XCTestCase {
    func testRmsFloorIsApplied() {
        let silent = [Float](repeating: 0, count: 1024)
        let rms = silent.withUnsafeBufferPointer { pointer in
            SPLCalculator.rms(from: pointer.baseAddress!, frameLength: silent.count)
        }
        XCTAssertGreaterThanOrEqual(rms, SPLCalculator.rmsFloor)
    }

    func testSplIncreasesWithCalibrationOffset() {
        let rms: Float = 1.0
        let (_, base) = SPLCalculator.spl(fromRMS: rms, calibrationOffset: 100)
        let (_, shifted) = SPLCalculator.spl(fromRMS: rms, calibrationOffset: 110)
        XCTAssertEqual(shifted - base, 10, accuracy: 0.01)
    }
}
