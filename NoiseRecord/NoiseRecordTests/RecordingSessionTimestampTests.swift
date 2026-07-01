import XCTest
@testable import NoiseRecord

final class RecordingSessionTimestampTests: XCTestCase {
    func testParseStartDateFromPrefixedSegmentFileName() {
        let date = RecordingSession.parseStartDate(from: "S_20260701_180613.m4a")
        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.minute, 6)
        XCTAssertEqual(components.second, 13)
    }

    func testParseStartDateFromPrefixedSessionFileName() {
        let date = RecordingSession.parseStartDate(from: "F_20260701_180612.m4a")
        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date!)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.minute, 6)
        XCTAssertEqual(components.second, 12)
    }

    func testParseStartDateFromLegacyVADSegmentFileName() {
        let date = RecordingSession.parseStartDate(from: "20260701_180613_55dB.m4a")
        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.minute, 6)
        XCTAssertEqual(components.second, 13)
    }

    func testParseStartDateFromLegacySessionFileName() {
        let date = RecordingSession.parseStartDate(from: "20260701_180612_session.m4a")
        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date!)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.minute, 6)
        XCTAssertEqual(components.second, 12)
    }

    func testRecordingStartDatePrefersFileNameForFirstSegment() {
        let parsed = RecordingSession.parseStartDate(from: "S_20260701_180613.m4a")!
        let session = RecordingSession(
            fileName: "S_20260701_180613.m4a",
            filePath: "Recordings/S_20260701_180613.m4a",
            startedAt: parsed.addingTimeInterval(31),
            endedAt: parsed.addingTimeInterval(62),
            peakDB: 55,
            averageDB: 50,
            segmentIndex: 1
        )

        XCTAssertEqual(session.recordingStartDate, parsed)
        XCTAssertEqual(session.duration, 62, accuracy: 0.001)
    }
}
