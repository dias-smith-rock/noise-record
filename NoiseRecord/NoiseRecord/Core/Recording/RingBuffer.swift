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
final class PCMFrameAccumulator {
    private var frames: [Float] = []
    let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func append(_ samples: UnsafePointer<Float>, count: Int) {
        frames.append(contentsOf: UnsafeBufferPointer(start: samples, count: count))
    }

    func appendFromArray(_ samples: [Float]) {
        frames.append(contentsOf: samples)
    }

    func drain(into file: AVAudioFile, format: AVAudioFormat) throws {
        guard !frames.isEmpty else { return }
        let frameCount = AVAudioFrameCount(frames.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<frames.count {
                channelData[i] = frames[i]
            }
        }
        try file.write(from: buffer)
        frames.removeAll(keepingCapacity: true)
    }

    var isEmpty: Bool { frames.isEmpty }

    func reset() {
        frames.removeAll()
    }
}
