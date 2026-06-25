import XCTest
@testable import NoiseRecord

final class VoiceActivatedRecorderSegmentTests: XCTestCase {
    func testSegmentFileNameFirstPartOmitsSuffix() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSegmentFileName(
                timestamp: "20260410_153045",
                peakDB: 65,
                index: 1
            ),
            "20260410_153045_65dB.m4a"
        )
    }

    func testSegmentFileNameSecondPartUsesPartSuffix() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSegmentFileName(
                timestamp: "20260410_153045",
                peakDB: 65,
                index: 2
            ),
            "20260410_153045_65dB_part2.m4a"
        )
    }
}
