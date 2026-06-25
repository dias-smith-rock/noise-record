import XCTest
@testable import NoiseRecord

final class VideoNoiseRecorderSegmentTests: XCTestCase {
    func testSegmentFileNameFirstPartOmitsSuffix() {
        XCTAssertEqual(
            VideoNoiseRecorder.makeSegmentFileName(timestamp: "20260410_153045", segmentIndex: 1),
            "evidence_20260410_153045.mp4"
        )
    }

    func testSegmentFileNameSecondPartUsesPartSuffix() {
        XCTAssertEqual(
            VideoNoiseRecorder.makeSegmentFileName(timestamp: "20260410_153045", segmentIndex: 2),
            "evidence_20260410_153045_part2.mp4"
        )
    }

    func testSegmentPartURLUsesPartExtension() {
        let url = VideoNoiseRecorder.makeSegmentPartURL(timestamp: "20260410_153045", segmentIndex: 1)
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".mp4.part"))
        XCTAssertEqual(url.lastPathComponent, "evidence_20260410_153045.mp4.part")
    }
}

// MARK: - Manual long-recording checklist
//
// 1. Set `VideoNoiseRecorder.maxSegmentDuration` to 30s in a debug build, record ≥90s, confirm
//    `_part2` / `_part3` files appear in Files and each segment plays independently.
// 2. Switch away from the Video tab while recording; verify the last segment is saved and listed.
// 3. Send the app to background during recording; confirm a new segment starts after foreground resume.
// 4. Simulate an incoming call (or audio interruption); confirm the current segment is finalized.
// 5. Restore `maxSegmentDuration` to 600s and run a ≥30 min foreground capture; all segments must
//    finish with `finishWriting` success and playable MP4 output.
