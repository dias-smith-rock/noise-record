import Foundation

struct NoiseTimelineMetrics: Sendable, Equatable {
    let duration: TimeInterval
    let peakDB: Float
    let maximumDB: Float
    let laeqDB: Float?
    let timeAveragedDB: Float?
    let dosePercent: Double
    let projectedDosePercent: Double
    let weighting: String

    static func compute(
        from timeline: VideoNoiseTimeline?,
        sessionDuration: TimeInterval,
        fallbackPeak: Float,
        fallbackAverage: Float
    ) -> NoiseTimelineMetrics {
        guard let timeline, !timeline.samples.isEmpty else {
            let duration = max(sessionDuration, 0)
            return NoiseTimelineMetrics(
                duration: duration,
                peakDB: fallbackPeak,
                maximumDB: fallbackPeak,
                laeqDB: duration > 0 ? fallbackAverage : nil,
                timeAveragedDB: duration >= 5 ? fallbackAverage : nil,
                dosePercent: 0,
                projectedDosePercent: 0,
                weighting: "dBA"
            )
        }

        let samples = timeline.samples
        let peak = samples.map(\.decibel).max() ?? fallbackPeak
        let maximum = peak
        let duration = max(
            sessionDuration,
            samples.last?.time ?? 0,
            sampleSpanDuration(samples)
        )
        let laeq = laeq(from: samples)
        let timeAveraged = duration >= 5 ? laeq : nil
        let dose = dosePercent(laeq: laeq, duration: duration)
        let projected = projectedDosePercent(laeq: laeq, duration: duration)

        return NoiseTimelineMetrics(
            duration: duration,
            peakDB: peak,
            maximumDB: maximum,
            laeqDB: laeq,
            timeAveragedDB: timeAveraged,
            dosePercent: dose,
            projectedDosePercent: projected,
            weighting: timeline.weighting
        )
    }

    private static func sampleSpanDuration(_ samples: [VideoNoiseSample]) -> TimeInterval {
        guard samples.count > 1 else { return 0 }
        return samples.last!.time - samples.first!.time
    }

    private static func laeq(from samples: [VideoNoiseSample]) -> Float? {
        guard !samples.isEmpty else { return nil }

        var energySum = 0.0
        var totalDuration = 0.0
        let defaultStep = 0.1

        for index in samples.indices {
            let sample = samples[index]
            let step: Double
            if index + 1 < samples.count {
                step = max(samples[index + 1].time - sample.time, 0)
            } else if index > 0 {
                step = max(sample.time - samples[index - 1].time, defaultStep)
            } else {
                step = defaultStep
            }

            guard step > 0 else { continue }
            let linear = pow(10.0, Double(sample.decibel) / 10.0)
            energySum += linear * step
            totalDuration += step
        }

        guard totalDuration > 0, energySum > 0 else { return nil }
        return Float(10.0 * log10(energySum / totalDuration))
    }

    private static func dosePercent(laeq: Float?, duration: TimeInterval) -> Double {
        guard let laeq, duration > 0, laeq >= ExposureStandards.thresholdLevelDB else { return 0 }
        let ratio = duration / ExposureStandards.criterionDurationSeconds
        let exponent = Double(laeq - ExposureStandards.criterionLevelDB) / Double(ExposureStandards.exchangeRateDB)
        return min(100, ratio * pow(10, exponent) * 100)
    }

    private static func projectedDosePercent(laeq: Float?, duration: TimeInterval) -> Double {
        guard let laeq, duration > 0 else { return 0 }
        let current = dosePercent(laeq: laeq, duration: duration)
        guard current > 0 else { return 0 }
        let projected = current * (ExposureStandards.criterionDurationSeconds / duration)
        return min(100, projected)
    }
}
