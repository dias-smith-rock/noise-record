import XCTest
@testable import NoiseRecord

final class VoiceThresholdValidatorTests: XCTestCase {
    func testNormalizeWhenHighNotGreaterThanLow() {
        let result = VoiceThresholdValidator.normalized(high: 50, low: 50)
        XCTAssertGreaterThan(result.high, result.low)
    }

    func testPreservesValidPair() {
        let result = VoiceThresholdValidator.normalized(high: 60, low: 48)
        XCTAssertEqual(result.high, 60)
        XCTAssertEqual(result.low, 48)
    }
}
