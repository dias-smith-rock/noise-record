import SwiftUI
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
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 10), L10n.gaugeAmbientTotalSilence)
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 35), L10n.gaugeAmbientQuietLibrary)
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 55), L10n.gaugeAmbientNormalConversation)
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 72), L10n.gaugeAmbientCityTraffic)
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 90), L10n.gaugeAmbientLawnMower)
        XCTAssertEqual(AcousticGaugeStyle.ambientNoiseDescription(forDecibel: 120), L10n.gaugeAmbientJetTakeoff)
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

    func testGreenYellowSplitNear55Decibels() {
        let belowSplit = AcousticGaugeStyle.color(forDecibel: 48)
        let atSplit = AcousticGaugeStyle.color(forDecibel: 55)
        let yellow = Color(hex: "#FBBF24")
        XCTAssertEqual(atSplit, yellow)
        XCTAssertNotEqual(belowSplit, atSplit)
    }

    func testYellowRedSplitNear90Decibels() {
        let belowSplit = AcousticGaugeStyle.color(forDecibel: 80)
        let atSplit = AcousticGaugeStyle.color(forDecibel: 90)
        let orangeBridge = Color(hex: "#F97316")
        XCTAssertEqual(atSplit, orangeBridge)
        XCTAssertNotEqual(belowSplit, atSplit)
    }

    func testSegmentMidpointColorMatchesMeanDecibel() {
        let segment = AcousticGaugeStyle.color(forDecibel: (50 + 80) * 0.5)
        let direct = AcousticGaugeStyle.color(forDecibel: 65)
        XCTAssertEqual(segment, direct)
    }
}
