import XCTest
@testable import NoiseRecord

final class MonitorSettingsStoreTests: XCTestCase {
    private let autoStartKey = "settings.autoStartMonitoringOnLaunch"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: autoStartKey)
        super.tearDown()
    }

    func testAutoStartMonitoringDefaultsToTrueWhenUnset() {
        UserDefaults.standard.removeObject(forKey: autoStartKey)
        XCTAssertTrue(MonitorSettingsStore.autoStartMonitoringOnLaunch)
    }

    func testAutoStartMonitoringCanBeDisabled() {
        MonitorSettingsStore.autoStartMonitoringOnLaunch = false
        XCTAssertFalse(MonitorSettingsStore.autoStartMonitoringOnLaunch)
    }
}
