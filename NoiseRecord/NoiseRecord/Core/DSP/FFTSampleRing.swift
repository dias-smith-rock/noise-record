import Foundation

/// Ring buffer for FFT framing — keeps the latest N samples with O(1) writes.
struct FFTSampleRing {
    private var storage: [Float]
    private var writeIndex = 0
    private(set) var filled = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = [Float](repeating: 0, count: self.capacity)
    }

    mutating func write(_ samples: UnsafePointer<Float>, count: Int) {
        for i in 0..<count {
            storage[writeIndex] = samples[i]
            writeIndex = (writeIndex + 1) % capacity
            filled = min(filled + 1, capacity)
        }
    }

    mutating func reset() {
        writeIndex = 0
        filled = 0
    }

    var isReadyForAnalysis: Bool { filled >= capacity }

    /// Copies the most recent `capacity` samples into `scratch` in chronological order.
    func copyLatestWindow(into scratch: inout [Float]) {
        guard filled >= capacity, scratch.count >= capacity else { return }
        let start = (writeIndex - capacity + capacity) % capacity
        if start + capacity <= capacity {
            scratch[0..<capacity] = storage[start..<(start + capacity)]
        } else {
            let firstPart = capacity - start
            scratch[0..<firstPart] = storage[start..<capacity]
            scratch[firstPart..<capacity] = storage[0..<(capacity - firstPart)]
        }
    }
}
