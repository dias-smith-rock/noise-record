import XCTest
@testable import NoiseRecord

final class WidgetSnapshotStoreTests: XCTestCase {
    private let snapshotKey = "widget.monitoringSnapshot"
    private let pendingActionKey = "widget.pendingAction"

    override func tearDown() {
        let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier)
        defaults?.removeObject(forKey: snapshotKey)
        defaults?.removeObject(forKey: pendingActionKey)
        super.tearDown()
    }

    func testSaveLoadRoundTrip() {
        let snapshot = WidgetMonitoringSnapshot(
            currentDB: 55.5,
            maxDB: 70.2,
            minDB: 40.1,
            averageDB: 52.0,
            leq: 51.3,
            weightingBadge: "A",
            isHighSensitivity: false,
            isMonitoring: true,
            recordingState: .recording,
            history: [40, 45, 55],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        WidgetSnapshotStore.save(snapshot)
        let loaded = WidgetSnapshotStore.load()

        XCTAssertEqual(loaded, snapshot)
    }

    func testPendingActionRoundTrip() {
        XCTAssertNil(WidgetSnapshotStore.pendingAction)
        WidgetSnapshotStore.pendingAction = .start
        XCTAssertEqual(WidgetSnapshotStore.pendingAction, .start)
        WidgetSnapshotStore.pendingAction = nil
        XCTAssertNil(WidgetSnapshotStore.pendingAction)
    }

    func testPlaceholderHasNoData() {
        XCTAssertFalse(WidgetMonitoringSnapshot.placeholder.hasData)
    }
}
