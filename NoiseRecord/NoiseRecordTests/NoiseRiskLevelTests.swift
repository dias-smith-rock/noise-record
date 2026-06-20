import XCTest
@testable import NoiseRecord

final class NoiseRiskLevelTests: XCTestCase {
    func testStandardQuietThreshold() {
        XCTAssertEqual(NoiseRiskLevel.from(db: 35, highSensitivity: false), .quiet)
        XCTAssertEqual(NoiseRiskLevel.from(db: 50, highSensitivity: false), .moderate)
        XCTAssertEqual(NoiseRiskLevel.from(db: 70, highSensitivity: false), .loud)
        XCTAssertEqual(NoiseRiskLevel.from(db: 85, highSensitivity: false), .dangerous)
    }

    func testHighSensitivityThresholds() {
        XCTAssertEqual(NoiseRiskLevel.from(db: 40, highSensitivity: true), .quiet)
        XCTAssertEqual(NoiseRiskLevel.from(db: 55, highSensitivity: true), .moderate)
        XCTAssertEqual(NoiseRiskLevel.from(db: 75, highSensitivity: true), .loud)
        XCTAssertEqual(NoiseRiskLevel.from(db: 90, highSensitivity: true), .dangerous)
    }
}
