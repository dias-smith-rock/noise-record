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

/// Sliding-window average for short-term display smoothing.
struct SlidingAverage {
    private var samples: [Float] = []
    private let windowSize: Int

    init(windowSize: Int = 30) {
        self.windowSize = windowSize
    }

    mutating func add(_ value: Float) -> Float {
        samples.append(value)
        if samples.count > windowSize {
            samples.removeFirst(samples.count - windowSize)
        }
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Float(samples.count)
    }

    mutating func reset() {
        samples.removeAll()
    }
}
