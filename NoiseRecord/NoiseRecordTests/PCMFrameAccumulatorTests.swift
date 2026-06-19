import AVFoundation
import XCTest
@testable import NoiseRecord

final class PCMFrameAccumulatorTests: XCTestCase {
    private func makeTempAudioFile(sampleRate: Double = 44_100) throws -> (AVAudioFile, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pcm_accumulator_\(UUID().uuidString).m4a")
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
        return (file, url)
    }

    func testDrainWritesAllSamplesInOrder() throws {
        let accumulator = PCMFrameAccumulator(sampleRate: 44_100)
        let (file, url) = try makeTempAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let firstBatch: [Float] = [0.1, 0.2, 0.3]
        let secondBatch: [Float] = [0.4, 0.5]
        accumulator.appendFromArray(firstBatch)
        accumulator.appendFromArray(secondBatch)

        try accumulator.drain(into: file, format: file.processingFormat)

        XCTAssertTrue(accumulator.isEmpty)
    }

    func testDrainChunksLargeSnapshot() throws {
        let accumulator = PCMFrameAccumulator(sampleRate: 44_100)
        let (file, url) = try makeTempAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let sampleCount = 20_000
        let samples = [Float](repeating: 0.25, count: sampleCount)
        accumulator.appendFromArray(samples)

        try accumulator.drain(into: file, format: file.processingFormat)

        XCTAssertTrue(accumulator.isEmpty)
    }

    func testConcurrentAppendAndDrainDoesNotCrash() throws {
        let accumulator = PCMFrameAccumulator(sampleRate: 44_100)
        let (file, url) = try makeTempAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let appendDone = expectation(description: "append")
        let drainDone = expectation(description: "drain")

        let appendQueue = DispatchQueue(label: "test.pcm.append", qos: .userInteractive)
        let drainQueue = DispatchQueue(label: "test.pcm.drain", qos: .utility)

        appendQueue.async {
            for batch in 0..<200 {
                var samples = [Float](repeating: Float(batch) * 0.001, count: 512)
                samples.withUnsafeBufferPointer { pointer in
                    guard let base = pointer.baseAddress else { return }
                    accumulator.append(base, count: 512)
                }
            }
            appendDone.fulfill()
        }

        drainQueue.async {
            for _ in 0..<100 {
                try? accumulator.drain(into: file, format: file.processingFormat)
                usleep(1_000)
            }
            drainDone.fulfill()
        }

        wait(for: [appendDone, drainDone], timeout: 30)

        try accumulator.drain(into: file, format: file.processingFormat)
        XCTAssertTrue(accumulator.isEmpty)
    }

    func testResetWhileDrainInFlightDoesNotCrash() throws {
        let accumulator = PCMFrameAccumulator(sampleRate: 44_100)
        let (file, url) = try makeTempAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        accumulator.appendFromArray([Float](repeating: 0.5, count: 4096))

        let drainDone = expectation(description: "drain")
        let resetDone = expectation(description: "reset")

        DispatchQueue.global(qos: .utility).async {
            for _ in 0..<100 {
                try? accumulator.drain(into: file, format: file.processingFormat)
            }
            drainDone.fulfill()
        }

        DispatchQueue.global(qos: .userInteractive).async {
            for batch in 0..<200 {
                var samples = [Float](repeating: Float(batch), count: 256)
                samples.withUnsafeBufferPointer { pointer in
                    guard let base = pointer.baseAddress else { return }
                    accumulator.append(base, count: 256)
                }
                if batch % 20 == 0 {
                    accumulator.reset()
                }
            }
            resetDone.fulfill()
        }

        wait(for: [drainDone, resetDone], timeout: 30)
    }
}
