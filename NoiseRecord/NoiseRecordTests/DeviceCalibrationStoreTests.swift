import XCTest
@testable import NoiseRecord

final class DeviceCalibrationStoreTests: XCTestCase {
    private let userAdjustmentKey = "calibration.userAdjustment"
    private let referenceSPLKey = "calibration.referenceSPL"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: userAdjustmentKey)
        UserDefaults.standard.removeObject(forKey: referenceSPLKey)
        super.tearDown()
    }

    func testUserAdjustmentPersistsAcrossReads() {
        DeviceCalibrationStore.userAdjustment = 3.5
        XCTAssertEqual(DeviceCalibrationStore.userAdjustment, 3.5, accuracy: 0.001)
    }

    func testCalibratePersistsReferenceSPLAndUserAdjustment() {
        DeviceCalibrationStore.calibrate(referenceSPL: 88, measuredDBFS: -32)
        XCTAssertEqual(DeviceCalibrationStore.referenceSPL, 88, accuracy: 0.001)
        XCTAssertNotEqual(DeviceCalibrationStore.userAdjustment, 0)
    }

    func testResetCalibrationClearsUserAdjustmentOnly() {
        DeviceCalibrationStore.calibrate(referenceSPL: 100, measuredDBFS: -28)
        DeviceCalibrationStore.resetCalibration()
        XCTAssertEqual(DeviceCalibrationStore.userAdjustment, 0, accuracy: 0.001)
        XCTAssertEqual(DeviceCalibrationStore.referenceSPL, 100, accuracy: 0.001)
    }
}
