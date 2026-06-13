import XCTest
@testable import NoiseRecord

final class SlidingAverageTests: XCTestCase {
    func testRingBufferAverage() {
        var average = SlidingAverage(windowSize: 3)
        XCTAssertEqual(average.add(10), 10, accuracy: 0.001)
        XCTAssertEqual(average.add(20), 15, accuracy: 0.001)
        XCTAssertEqual(average.add(30), 20, accuracy: 0.001)
        XCTAssertEqual(average.add(40), 30, accuracy: 0.001)
    }
}
