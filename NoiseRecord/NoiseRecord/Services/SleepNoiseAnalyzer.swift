import Foundation

struct SleepAnomalyCandidate: Sendable, Equatable {
    let timestamp: Date
    let peakDB: Float
    let durationSeconds: Float
}

enum SleepNoiseAnalyzer {
    static let anomalyMinimumDuration: TimeInterval = 3
    static let liveAnomalyMinimumDuration: TimeInterval = 2
    static let standardAnomalyFloorDeltaDB: Float = 12
    static let highSensitivityAnomalyFloorDeltaDB: Float = 8
    static let floorPercentile: Float = 0.10

    static func anomalyFloorDelta(isHighSensitivity: Bool) -> Float {
        isHighSensitivity ? highSensitivityAnomalyFloorDeltaDB : standardAnomalyFloorDeltaDB
    }

    static func noiseFloor(from leqValues: [Float]) -> Float {
        guard !leqValues.isEmpty else { return 0 }
        let sorted = leqValues.sorted()
        let index = max(0, Int(Float(sorted.count - 1) * floorPercentile))
        return sorted[index]
    }

    static func overallLeq(from leqValues: [Float]) -> Float {
        guard !leqValues.isEmpty else { return 0 }
        var energySum: Float = 0
        for value in leqValues {
            energySum += powf(10, value / 10)
        }
        let meanEnergy = energySum / Float(leqValues.count)
        return 10 * log10f(max(meanEnergy, 1e-12))
    }

    static func peakDB(from samples: [(timestamp: Date, leq: Float, peak: Float)]) -> Float {
        samples.map(\.peak).max() ?? 0
    }

    static func detectAnomalies(
        samples: [(timestamp: Date, leq: Float, peak: Float)],
        noiseFloor: Float,
        referenceDB: Float,
        isHighSensitivity: Bool = false,
        referenceTime: Date = Date(),
        includeOngoing: Bool = false,
        minimumDuration: TimeInterval? = nil
    ) -> [SleepAnomalyCandidate] {
        guard !samples.isEmpty else { return [] }

        let floorDelta = anomalyFloorDelta(isHighSensitivity: isHighSensitivity)
        let requiredDuration = minimumDuration ?? anomalyMinimumDuration
        var results: [SleepAnomalyCandidate] = []
        var activeStart: Date?
        var activePeak: Float = 0

        for sample in samples {
            let isAnomaly = sample.peak >= noiseFloor + floorDelta
                || (!isHighSensitivity && sample.peak >= referenceDB)

            if isAnomaly {
                if activeStart == nil {
                    activeStart = sample.timestamp
                    activePeak = sample.peak
                } else {
                    activePeak = max(activePeak, sample.peak)
                }
            } else if let start = activeStart {
                appendAnomalyIfLongEnough(
                    start: start,
                    end: sample.timestamp,
                    peak: activePeak,
                    minimumDuration: requiredDuration,
                    into: &results
                )
                activeStart = nil
                activePeak = 0
            }
        }

        if let start = activeStart {
            let end = includeOngoing ? referenceTime : samples.last?.timestamp ?? referenceTime
            appendAnomalyIfLongEnough(
                start: start,
                end: end,
                peak: activePeak,
                minimumDuration: requiredDuration,
                into: &results
            )
        }

        return results
    }

    private static func appendAnomalyIfLongEnough(
        start: Date,
        end: Date,
        peak: Float,
        minimumDuration: TimeInterval = anomalyMinimumDuration,
        into results: inout [SleepAnomalyCandidate]
    ) {
        let duration = end.timeIntervalSince(start)
        guard duration >= minimumDuration else { return }
        results.append(
            SleepAnomalyCandidate(
                timestamp: start,
                peakDB: peak,
                durationSeconds: Float(duration)
            )
        )
    }

    static func sleepImpactHint(for timestamp: Date, calendar: Calendar = .current) -> SleepImpactHint {
        let hour = calendar.component(.hour, from: timestamp)
        if (1...4).contains(hour) {
            return .deepSleep
        }
        return .lightSleep
    }

    static func finalize(
        samples: [(timestamp: Date, leq: Float, peak: Float)],
        referenceDB: Float,
        isHighSensitivity: Bool = false
    ) -> (
        noiseFloor: Float,
        overallLeq: Float,
        peakDB: Float,
        anomalies: [SleepAnomalyCandidate]
    ) {
        let leqValues = samples.map(\.leq)
        let floor = noiseFloor(from: leqValues)
        let leq = overallLeq(from: leqValues)
        let peak = peakDB(from: samples)
        let anomalies = detectAnomalies(
            samples: samples,
            noiseFloor: floor,
            referenceDB: referenceDB,
            isHighSensitivity: isHighSensitivity
        )
        return (floor, leq, peak, anomalies)
    }

    static func samplesFromRecentLevels(
        _ levels: [Float],
        interval: TimeInterval,
        endingAt: Date = Date()
    ) -> [(timestamp: Date, leq: Float, peak: Float)] {
        guard !levels.isEmpty else { return [] }
        let start = endingAt.addingTimeInterval(-Double(levels.count) * interval)
        return levels.enumerated().compactMap { index, level in
            guard level > 0 else { return nil }
            return (
                timestamp: start.addingTimeInterval(Double(index) * interval),
                leq: level,
                peak: level
            )
        }
    }

    static func mergeReportSamples(
        persisted: [(timestamp: Date, leq: Float, peak: Float)],
        inMemory: [(timestamp: Date, leq: Float, peak: Float)],
        recentLevels: [Float],
        recentInterval: TimeInterval,
        finalSnapshot: (timestamp: Date, leq: Float, peak: Float)?
    ) -> [(timestamp: Date, leq: Float, peak: Float)] {
        var merged = inMemory.filter { $0.leq > 0 }
        if merged.count < 2 {
            merged = persisted.filter { $0.leq > 0 }
        }
        if merged.count < 2 {
            merged = samplesFromRecentLevels(
                recentLevels,
                interval: recentInterval
            )
        }

        if merged.isEmpty, let finalSnapshot, finalSnapshot.leq > 0 {
            merged = [finalSnapshot]
        } else if let finalSnapshot, finalSnapshot.leq > 0 {
            merged.append(finalSnapshot)
        }

        return merged.sorted { $0.timestamp < $1.timestamp }
    }

    /// Live banner noise floor from a rolling recent window (not session-wide minimum).
    static func liveNoiseFloor(
        recentLevels: [Float],
        persistedLeqSamples: [Float],
        minimumRecentSamples: Int = 5,
        percentileWindowSize: Int = 30
    ) -> Float? {
        let validRecent = recentLevels.filter { $0 > 0 }
        if validRecent.count >= minimumRecentSamples {
            if validRecent.count >= percentileWindowSize {
                return noiseFloor(from: validRecent)
            }
            let sorted = validRecent.sorted()
            return sorted[sorted.count / 2]
        }

        let validPersisted = persistedLeqSamples.filter { $0 > 0 }
        if !validPersisted.isEmpty {
            return noiseFloor(from: validPersisted)
        }

        if validRecent.count >= 2 {
            let sorted = validRecent.sorted()
            return sorted[sorted.count / 2]
        }

        return validRecent.min()
    }

    static func dynamicVADThresholds(
        noiseFloor: Float,
        isHighSensitivity: Bool = false
    ) -> (high: Float, low: Float) {
        let highDelta: Float = isHighSensitivity ? 10 : 15
        let minimumHigh: Float = isHighSensitivity ? 45 : 50
        let high = max(noiseFloor + highDelta, minimumHigh)
        let low = max(high - 7, isHighSensitivity ? 38 : 40)
        return (high, low)
    }
}
