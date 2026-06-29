import XCTest
@testable import NoiseRecord

final class DeviceCalibrationStoreTests: XCTestCase {
    private let userAdjustmentKey = "calibration.userAdjustment"
    private let referenceSPLKey = "calibration.referenceSPL"
    private let highSensitivityKey = "settings.highSensitivityMode"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: userAdjustmentKey)
        UserDefaults.standard.removeObject(forKey: referenceSPLKey)
        UserDefaults.standard.removeObject(forKey: highSensitivityKey)
        super.tearDown()
    }

    func testFirstInstallDefaultsToHighSensitivityMode() {
        UserDefaults.standard.removeObject(forKey: highSensitivityKey)
        XCTAssertTrue(DeviceCalibrationStore.isHighSensitivityMode)
    }

    func testExplicitHighSensitivityChoiceIsRespected() {
        DeviceCalibrationStore.isHighSensitivityMode = false
        XCTAssertFalse(DeviceCalibrationStore.isHighSensitivityMode)
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

    func testCalibrateDisplayedSPLShiftsUserAdjustmentByDelta() {
        DeviceCalibrationStore.userAdjustment = 5
        DeviceCalibrationStore.calibrate(referenceSPL: 94, displayedSPL: 72)
        XCTAssertEqual(DeviceCalibrationStore.userAdjustment, 27, accuracy: 0.001)
        XCTAssertEqual(DeviceCalibrationStore.referenceSPL, 94, accuracy: 0.001)
    }

    func testResetCalibrationClearsUserAdjustmentOnly() {
        DeviceCalibrationStore.calibrate(referenceSPL: 100, measuredDBFS: -28)
        DeviceCalibrationStore.resetCalibration()
        XCTAssertEqual(DeviceCalibrationStore.userAdjustment, 0, accuracy: 0.001)
        XCTAssertEqual(DeviceCalibrationStore.referenceSPL, 100, accuracy: 0.001)
    }

    func testDeviceOffsetForIPhone13MachineIdentifier() {
        XCTAssertEqual(DeviceCalibrationStore.deviceOffset(for: "iPhone14,5"), 115.0, accuracy: 0.001)
    }

    func testDeviceOffsetForIPhone13MiniMachineIdentifier() {
        XCTAssertEqual(DeviceCalibrationStore.deviceOffset(for: "iPhone14,4"), 115.0, accuracy: 0.001)
    }
}
