import XCTest
@testable import NoiseRecord

final class PlaybackMonitoringGateTests: XCTestCase {
    func testNoInterruptionWhenIdle() {
        XCTAssertEqual(
            PlaybackMonitoringGate.interruptionKind(
                isEngineMonitoring: false,
                isSleepMonitoring: false
            ),
            .none
        )
    }

    func testStandardInterruptionWhenEngineMonitoring() {
        XCTAssertEqual(
            PlaybackMonitoringGate.interruptionKind(
                isEngineMonitoring: true,
                isSleepMonitoring: false
            ),
            .standard
        )
    }

    func testSleepInterruptionTakesPriority() {
        XCTAssertEqual(
            PlaybackMonitoringGate.interruptionKind(
                isEngineMonitoring: true,
                isSleepMonitoring: true
            ),
            .sleep
        )
    }

    func testSleepInterruptionWhenOnlySleepSessionActive() {
        XCTAssertEqual(
            PlaybackMonitoringGate.interruptionKind(
                isEngineMonitoring: false,
                isSleepMonitoring: true
            ),
            .sleep
        )
    }
}
