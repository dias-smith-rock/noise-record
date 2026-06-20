import XCTest
@testable import NoiseRecord

final class WatchCalibrationStoreTests: XCTestCase {
    func testTotalOffsetIncludesUserAdjustment() {
        let original = WatchCalibrationStore.userAdjustment
        defer { WatchCalibrationStore.userAdjustment = original }

        WatchCalibrationStore.userAdjustment = 2.5
        XCTAssertEqual(
            WatchCalibrationStore.totalOffset,
            WatchCalibrationStore.deviceOffset + 2.5,
            accuracy: 0.001
        )
    }

    func testHighSensitivityUsesZWeighting() {
        let original = WatchCalibrationStore.isHighSensitivityMode
        defer { WatchCalibrationStore.isHighSensitivityMode = original }

        WatchCalibrationStore.isHighSensitivityMode = true
        XCTAssertEqual(WatchCalibrationStore.weightingType, .z)

        WatchCalibrationStore.isHighSensitivityMode = false
        XCTAssertEqual(WatchCalibrationStore.weightingType, .a)
    }
}
