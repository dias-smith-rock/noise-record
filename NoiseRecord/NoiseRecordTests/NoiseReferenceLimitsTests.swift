import XCTest
@testable import NoiseRecord

final class NoiseReferenceLimitsTests: XCTestCase {
    private let residentialNightKey = "settings.waveformResidentialNightReferenceDB"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: residentialNightKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: residentialNightKey)
        super.tearDown()
    }

    func testDefaultResidentialNightDBIsFiftyFive() {
        XCTAssertEqual(NoiseReferenceLimits.defaultResidentialNightDB, 55)
        XCTAssertEqual(NoiseReferenceLimits.residentialNightDB, 55)
        XCTAssertEqual(NoiseReferenceLimits.usResidentialNightDB, 55)
    }

    func testResidentialNightDBPersistsAndClamps() {
        NoiseReferenceLimits.residentialNightDB = 62
        XCTAssertEqual(NoiseReferenceLimits.residentialNightDB, 62)

        NoiseReferenceLimits.residentialNightDB = 999
        XCTAssertEqual(NoiseReferenceLimits.residentialNightDB, 75)

        NoiseReferenceLimits.residentialNightDB = 10
        XCTAssertEqual(NoiseReferenceLimits.residentialNightDB, 35)
    }

    func testResetRestoresDefault() {
        NoiseReferenceLimits.residentialNightDB = 60
        NoiseReferenceLimits.resetResidentialNightReference()
        XCTAssertEqual(NoiseReferenceLimits.residentialNightDB, 55)
    }

    func testShouldShowReferenceLineWhenInWaveformRange() {
        XCTAssertTrue(
            NoiseReferenceLimits.shouldShowReferenceLine(
                mode: .standard,
                showsReferenceLimitLine: true,
                referenceDB: 55
            )
        )
        XCTAssertTrue(
            NoiseReferenceLimits.shouldShowReferenceLine(
                mode: .highSensitivity,
                showsReferenceLimitLine: true,
                referenceDB: 55
            )
        )
        XCTAssertFalse(
            NoiseReferenceLimits.shouldShowReferenceLine(
                mode: .standard,
                showsReferenceLimitLine: false,
                referenceDB: 55
            )
        )
    }

    func testFiftyFiveIsWithinHighSensitivityWaveformRange() {
        let mode = AcousticMeasurementMode.highSensitivity
        XCTAssertTrue(NoiseReferenceLimits.isWithinWaveformRange(db: 55, mode: mode))
    }

    func testFiftyFiveIsWithinStandardWaveformRange() {
        let mode = AcousticMeasurementMode.standard
        XCTAssertTrue(NoiseReferenceLimits.isWithinWaveformRange(db: 55, mode: mode))

        let height: CGFloat = 120
        let y = waveformYPosition(
            for: 55,
            height: height,
            minDB: mode.waveformMinDB,
            maxDB: mode.waveformMaxDB
        )
        XCTAssertGreaterThan(y, 0)
        XCTAssertLessThan(y, height)
    }
}
