import Foundation

/// Fixed-capacity chronological float buffer without shifting elements on append.
struct FloatTimeSeriesBuffer {
    private var storage: [Float]
    private var writeIndex = 0
    private(set) var count = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = [Float](repeating: 0, count: self.capacity)
    }

    mutating func append(_ value: Float) {
        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    mutating func reset() {
        writeIndex = 0
        count = 0
    }

    /// Fills `target` with values in chronological order, reusing capacity when possible.
    func copyChronological(into target: inout [Float]) {
        target.removeAll(keepingCapacity: true)
        guard count > 0 else { return }
        target.reserveCapacity(count)
        let start = (writeIndex - count + capacity) % capacity
        if start + count <= capacity {
            target.append(contentsOf: storage[start..<(start + count)])
        } else {
            target.append(contentsOf: storage[start..<capacity])
            target.append(contentsOf: storage[0..<(count - (capacity - start))])
        }
    }
}
