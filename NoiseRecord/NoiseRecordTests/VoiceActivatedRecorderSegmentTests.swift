import AVFoundation
import XCTest
@testable import NoiseRecord

final class VoiceActivatedRecorderSegmentTests: XCTestCase {
    override func setUp() {
        super.setUp()
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func testSessionFileNameUsesFullPrefix() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSessionFileName(timestamp: "20260410_153045"),
            "F_20260410_153045.m4a"
        )
    }

    func testSegmentFileNameUsesSegmentPrefix() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSegmentFileName(timestamp: "20260410_153045", index: 1),
            "S_20260410_153045.m4a"
        )
    }

    func testSegmentFileNameSecondPartUsesShortPartSuffix() {
        XCTAssertEqual(
            VoiceActivatedRecorder.makeSegmentFileName(timestamp: "20260410_153045", index: 2),
            "S_20260410_153045_p2.m4a"
        )
    }

    func testFreeAndProSessionDurationLimits() {
        XCTAssertEqual(VoiceActivatedRecorder.freeMaxClipDuration, 180)
        XCTAssertEqual(VoiceActivatedRecorder.maxSessionDurationPro, 7200)
    }

    func testVADSegmentFinalizeEmitsEventWhileSessionContinues() throws {
        let recorder = VoiceActivatedRecorder()
        recorder.voiceActivatedEnabled = true
        recorder.highThreshold = 40
        recorder.lowThreshold = 30
        recorder.postRecordingDelay = 0
        recorder.preBufferDuration = 0.1
        recorder.locationSnapshot = { (37.33, -122.03) }

        let format = try makeMonoFormat()
        recorder.configure(sampleRate: format.sampleRate)

        var finishedEvents: [RecordingFinishedEvent] = []
        recorder.onRecordingFinished = { finishedEvents.append($0) }

        recorder.beginSession()

        let loud = [Float](repeating: 0.8, count: 4096)
        let quiet = [Float](repeating: 0.0001, count: 4096)

        loud.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for _ in 0..<8 {
                recorder.process(
                    filteredSamples: base,
                    frameLength: loud.count,
                    dbSPL: 70,
                    format: format
                )
            }
        }

        XCTAssertEqual(recorder.state, .recording)

        quiet.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for _ in 0..<40 {
                recorder.process(
                    filteredSamples: base,
                    frameLength: quiet.count,
                    dbSPL: 20,
                    format: format
                )
            }
        }

        XCTAssertEqual(recorder.state, .idle)
        XCTAssertEqual(finishedEvents.count, 1)
        XCTAssertFalse(finishedEvents[0].isSessionRecording)
        XCTAssertTrue(finishedEvents[0].fileURL.lastPathComponent.hasPrefix("S_"))
        XCTAssertEqual(finishedEvents[0].segmentIndex, 1)
        XCTAssertEqual(finishedEvents[0].latitude, 37.33)
        XCTAssertEqual(finishedEvents[0].longitude, -122.03)
        XCTAssertEqual(finishedEvents[0].segmentGroupID, finishedEvents[0].segmentGroupID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finishedEvents[0].fileURL.path))

        let endSessionEvents = recorder.endSession(
            peakDB: 70,
            averageDB: 55,
            noiseType: nil,
            latitude: 37.34,
            longitude: -122.04
        )
        finishedEvents.append(contentsOf: endSessionEvents)

        XCTAssertEqual(finishedEvents.count, 2)
        XCTAssertTrue(finishedEvents[1].isSessionRecording)
        XCTAssertTrue(finishedEvents[1].fileURL.lastPathComponent.hasPrefix("F_"))
        XCTAssertEqual(finishedEvents[1].segmentIndex, 0)
        XCTAssertEqual(finishedEvents[1].latitude, 37.34)
        XCTAssertEqual(finishedEvents[1].longitude, -122.04)
        XCTAssertEqual(finishedEvents[1].segmentGroupID, finishedEvents[0].segmentGroupID)
    }

    func testSegmentFinalizeWritesNoiseTimelineSidecar() throws {
        let recorder = VoiceActivatedRecorder()
        recorder.voiceActivatedEnabled = true
        recorder.highThreshold = 40
        recorder.lowThreshold = 30
        recorder.postRecordingDelay = 0
        recorder.preBufferDuration = 0.1

        let format = try makeMonoFormat()
        recorder.configure(sampleRate: format.sampleRate)

        var finishedURL: URL?
        recorder.onRecordingFinished = { finishedURL = $0.fileURL }

        recorder.beginSession()

        let loud = [Float](repeating: 0.8, count: 4096)
        let quiet = [Float](repeating: 0.0001, count: 4096)

        loud.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for _ in 0..<10 {
                recorder.process(
                    filteredSamples: base,
                    frameLength: loud.count,
                    dbSPL: 70,
                    format: format
                )
            }
        }

        quiet.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for _ in 0..<40 {
                recorder.process(
                    filteredSamples: base,
                    frameLength: quiet.count,
                    dbSPL: 20,
                    format: format
                )
            }
        }

        guard let url = finishedURL else {
            XCTFail("Expected segment file URL")
            return
        }

        let timeline = VideoNoiseTimelineStore.load(for: url)
        XCTAssertNotNil(timeline)
        XCTAssertFalse(timeline?.samples.isEmpty ?? true)
    }

    func testSessionRecordingSavedOnEndEvenWhenVADGated() throws {
        let recorder = VoiceActivatedRecorder()
        recorder.voiceActivatedEnabled = true
        recorder.highThreshold = 40
        recorder.lowThreshold = 30

        let format = try makeMonoFormat()
        recorder.configure(sampleRate: format.sampleRate)

        var finishedEvents: [RecordingFinishedEvent] = []
        recorder.onRecordingFinished = { finishedEvents.append($0) }

        recorder.beginSession()

        let loud = [Float](repeating: 0.8, count: 4096)
        loud.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for _ in 0..<6 {
                recorder.process(
                    filteredSamples: base,
                    frameLength: loud.count,
                    dbSPL: 70,
                    format: format,
                    vadGatedByFilter: false
                )
            }
        }

        let endSessionEvents = recorder.endSession(
            peakDB: 70,
            averageDB: 55,
            noiseType: nil,
            latitude: nil,
            longitude: nil
        )
        finishedEvents.append(contentsOf: endSessionEvents)

        XCTAssertEqual(finishedEvents.count, 1)
        XCTAssertTrue(finishedEvents[0].isSessionRecording)
        XCTAssertTrue(finishedEvents[0].fileURL.lastPathComponent.hasPrefix("F_"))
    }

    private func makeMonoFormat() throws -> AVAudioFormat {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "test", code: 1)
        }
        return format
    }
}
