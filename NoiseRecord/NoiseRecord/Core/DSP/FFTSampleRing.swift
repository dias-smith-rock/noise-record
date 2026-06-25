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

    func isReadyForAnalysis(windowSize: Int) -> Bool {
        filled >= min(windowSize, capacity)
    }

    /// Copies the most recent `windowSize` samples into `scratch` in chronological order.
    func copyLatestWindow(into scratch: inout [Float], windowSize: Int? = nil) {
        let window = windowSize ?? capacity
        guard filled >= window, scratch.count >= window, window <= capacity else { return }
        let start = (writeIndex - window + capacity) % capacity
        if start + window <= capacity {
            scratch[0..<window] = storage[start..<(start + window)]
        } else {
            let firstPart = capacity - start
            scratch[0..<firstPart] = storage[start..<capacity]
            scratch[firstPart..<window] = storage[0..<(window - firstPart)]
        }
    }

    /// Copies the most recent `capacity` samples into `scratch` in chronological order.
    func copyLatestWindow(into scratch: inout [Float]) {
        copyLatestWindow(into: &scratch, windowSize: capacity)
    }
}
