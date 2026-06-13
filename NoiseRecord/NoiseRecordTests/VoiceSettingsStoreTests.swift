import XCTest
@testable import NoiseRecord

final class VoiceSettingsStoreTests: XCTestCase {
    private let keys = [
        "settings.highThreshold",
        "settings.lowThreshold",
        "settings.voiceActivated",
        "settings.backgroundMonitoring",
        "settings.aiClassification",
        "settings.aiFilterLabels",
    ]

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    func testThresholdsPersistAcrossReads() {
        VoiceSettingsStore.highThreshold = 68
        VoiceSettingsStore.lowThreshold = 42
        XCTAssertEqual(VoiceSettingsStore.highThreshold, 68, accuracy: 0.001)
        XCTAssertEqual(VoiceSettingsStore.lowThreshold, 42, accuracy: 0.001)
    }

    func testAiFilterLabelsPersistAcrossReads() {
        VoiceSettingsStore.aiFilterLabels = ["speech", "dog", "alarm"]
        XCTAssertEqual(VoiceSettingsStore.aiFilterLabels, ["speech", "dog", "alarm"])
    }

    func testPersistWritesAllVoiceSettings() {
        VoiceSettingsStore.persist(
            highThreshold: 70,
            lowThreshold: 45,
            voiceActivatedEnabled: true,
            backgroundMonitoringEnabled: true,
            aiClassificationEnabled: true,
            aiFilterLabels: ["music", "car"]
        )
        XCTAssertEqual(VoiceSettingsStore.highThreshold, 70, accuracy: 0.001)
        XCTAssertEqual(VoiceSettingsStore.lowThreshold, 45, accuracy: 0.001)
        XCTAssertTrue(VoiceSettingsStore.voiceActivatedEnabled)
        XCTAssertTrue(VoiceSettingsStore.backgroundMonitoringEnabled)
        XCTAssertTrue(VoiceSettingsStore.aiClassificationEnabled)
        XCTAssertEqual(VoiceSettingsStore.aiFilterLabels, ["music", "car"])
    }
}
