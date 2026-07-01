import XCTest
@testable import NoiseRecord

final class AcousticGaugeStyleTests: XCTestCase {
    func testNormalizedPositionIsLinearAcrossZeroTo140() {
        XCTAssertEqual(AcousticGaugeStyle.normalizedPosition(forDecibel: 0), 0, accuracy: 0.001)
        XCTAssertEqual(AcousticGaugeStyle.normalizedPosition(forDecibel: 70), 0.5, accuracy: 0.001)
        XCTAssertEqual(AcousticGaugeStyle.normalizedPosition(forDecibel: 140), 1, accuracy: 0.001)
        XCTAssertEqual(AcousticGaugeStyle.normalizedPosition(forDecibel: 30), 30.0 / 140.0, accuracy: 0.001)
    }

    func testAngleSweepUses240DegreeArcFromDisplayMinimum() {
        XCTAssertEqual(AcousticGaugeStyle.angleDegrees(forDecibel: 20), 150, accuracy: 0.001)
        XCTAssertEqual(AcousticGaugeStyle.angleDegrees(forDecibel: 140), 390, accuracy: 0.001)
        XCTAssertEqual(AcousticGaugeStyle.angleDegrees(forDecibel: 80), 270, accuracy: 0.001)
    }

    func testAmbientDescriptionsForLifeScenarioBands() {
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 10), "Total Silence")
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 35), "Quiet Library / Whisper")
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 55), "Normal Conversation")
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 72), "City Traffic / Hairdryer")
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 90), "Lawn Mower / Alarm Siren")
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 120), "Jet Takeoff / Threshold of Pain")
    }

    func testZoneAccentUsesUpperBoundaryColor() {
        let quietAccent = AcousticGaugeStyle.zoneAccentColor(forDecibel: 25)
        let boundaryAccent = AcousticGaugeStyle.color(forDecibel: 30)
        XCTAssertEqual(quietAccent, boundaryAccent)
    }

    func testColorsDifferBetweenQuietAndLoudDecibels() {
        let quiet = AcousticGaugeStyle.color(forDecibel: 40)
        let loud = AcousticGaugeStyle.color(forDecibel: 90)
        XCTAssertNotEqual(quiet, loud)
    }

    func testSegmentMidpointColorMatchesMeanDecibel() {
        let segment = AcousticGaugeStyle.color(forDecibel: (50 + 80) * 0.5)
        let direct = AcousticGaugeStyle.color(forDecibel: 65)
        XCTAssertEqual(segment, direct)
    }
}
