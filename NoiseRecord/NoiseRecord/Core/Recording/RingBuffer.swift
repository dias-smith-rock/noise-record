import AVFoundation
import Foundation

/// Fixed-size circular PCM buffer for pre-recording capture.
final class RingBuffer {
    private var storage: [Float]
    private var writeIndex = 0
    private var filledCount = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = [Float](repeating: 0, count: capacity)
    }

    var isFull: Bool { filledCount == capacity }

    func write(_ samples: UnsafePointer<Float>, count: Int) {
        for i in 0..<count {
            storage[writeIndex] = samples[i]
            writeIndex = (writeIndex + 1) % capacity
            filledCount = min(filledCount + 1, capacity)
        }
    }

    func readAll() -> [Float] {
        guard filledCount > 0 else { return [] }
        var result = [Float](repeating: 0, count: filledCount)
        let start = (writeIndex - filledCount + capacity) % capacity
        for i in 0..<filledCount {
            result[i] = storage[(start + i) % capacity]
        }
        return result
    }

    func reset() {
        writeIndex = 0
        filledCount = 0
        storage = [Float](repeating: 0, count: capacity)
    }
}

/// Accumulates PCM frames for writing to AVAudioFile.
/// Thread-safe: append runs on the audio processing queue; drain runs on the file I/O queue.
final class PCMFrameAccumulator {
    private var frames: [Float] = []
    private let lock = NSLock()
    let sampleRate: Double

    private static let drainChunkSize = 8192

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func append(_ samples: UnsafePointer<Float>, count: Int) {
        lock.lock()
        frames.append(contentsOf: UnsafeBufferPointer(start: samples, count: count))
        lock.unlock()
    }

    func appendFromArray(_ samples: [Float]) {
        lock.lock()
        frames.append(contentsOf: samples)
        lock.unlock()
    }

    func drain(into file: AVAudioFile, format: AVAudioFormat) throws {
        let snapshot = takeSnapshotForDrain()
        guard !snapshot.isEmpty else { return }

        var offset = 0
        while offset < snapshot.count {
            let chunkCount = min(Self.drainChunkSize, snapshot.count - offset)
            let frameCount = AVAudioFrameCount(chunkCount)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount
            if let channelData = buffer.floatChannelData?[0] {
                for i in 0..<chunkCount {
                    channelData[i] = snapshot[offset + i]
                }
            }
            try file.write(from: buffer)
            offset += chunkCount
        }
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return frames.isEmpty
    }

    func reset() {
        lock.lock()
        frames.removeAll()
        lock.unlock()
    }

    private func takeSnapshotForDrain() -> [Float] {
        lock.lock()
        let snapshot = frames
        frames.removeAll(keepingCapacity: true)
        lock.unlock()
        return snapshot
    }
}
