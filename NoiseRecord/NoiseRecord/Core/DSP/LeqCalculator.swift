import Foundation

/// IEC-style equivalent continuous sound level integrator.
struct LeqCalculator: Sendable {
    private(set) var energySum: Double = 0
    private(set) var duration: TimeInterval = 0
    private var lastTimestamp: Date?

    var leq: Float {
        guard duration > 0 else { return 0 }
        let meanEnergy = energySum / duration
        guard meanEnergy > 0 else { return 0 }
        return Float(10.0 * log10(meanEnergy))
    }

    mutating func reset() {
        energySum = 0
        duration = 0
        lastTimestamp = nil
    }

    mutating func addSample(dbSPL: Float, at timestamp: Date = Date()) {
        let linear = pow(10.0, Double(dbSPL) / 10.0)
        if let last = lastTimestamp {
            let delta = timestamp.timeIntervalSince(last)
            guard delta > 0 else { return }
            energySum += linear * delta
            duration += delta
        }
        lastTimestamp = timestamp
    }

    mutating func finalizeOpenInterval(at timestamp: Date = Date()) {
        guard let last = lastTimestamp else { return }
        let delta = timestamp.timeIntervalSince(last)
        guard delta > 0 else { return }
        duration += delta
        lastTimestamp = timestamp
    }
}

/// Sliding-window average for short-term display smoothing (O(1) ring buffer).
struct SlidingAverage {
    private var buffer: [Float]
    private var writeIndex = 0
    private var count = 0
    private var sum: Float = 0
    private let windowSize: Int

    init(windowSize: Int = 30) {
        self.windowSize = windowSize
        self.buffer = [Float](repeating: 0, count: windowSize)
    }

    mutating func add(_ value: Float) -> Float {
        if count < windowSize {
            buffer[count] = value
            sum += value
            count += 1
        } else {
            let replaced = buffer[writeIndex]
            sum -= replaced
            buffer[writeIndex] = value
            sum += value
            writeIndex = (writeIndex + 1) % windowSize
        }
        guard count > 0 else { return 0 }
        return sum / Float(count)
    }

    mutating func reset() {
        writeIndex = 0
        count = 0
        sum = 0
    }
}
