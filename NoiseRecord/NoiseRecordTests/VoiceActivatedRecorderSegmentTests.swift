import XCTest
@testable import NoiseRecord

final class VoiceActivatedRecorderSegmentTests: XCTestCase {
    func testSessionFileNameUsesSessionSuffix() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSessionFileName(timestamp: "20260410_153045"),
            "20260410_153045_session.m4a"
        )
    }

    func testLegacySegmentFileNameFirstPartUsesSessionName() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSegmentFileName(
                timestamp: "20260410_153045",
                peakDB: 65,
                index: 1
            ),
            "20260410_153045_session.m4a"
        )
    }

    func testLegacySegmentFileNameSecondPartUsesPartSuffix() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSegmentFileName(
                timestamp: "20260410_153045",
                peakDB: 65,
                index: 2
            ),
            "20260410_153045_session_part2.m4a"
        )
    }

    func testFreeAndProSessionDurationLimits() {
        XCTAssertEqual(VoiceActivatedRecorder.freeMaxClipDuration, 180)
        XCTAssertEqual(VoiceActivatedRecorder.maxSessionDurationPro, 7200)
    }
}
