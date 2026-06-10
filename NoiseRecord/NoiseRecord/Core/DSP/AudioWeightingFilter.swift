import Accelerate
import Foundation

/// IEC 61672-1 inspired A/C weighting via cascaded biquad IIR filters.
final class AudioWeightingFilter {
    private var biquadSetup: vDSP_biquad_Setup?
    private var delayBuffer: [Float] = []
    private var floatScratch: [Float] = []
    private(set) var weightingType: WeightingType
    private let sampleRate: Double

    init(type: WeightingType, sampleRate: Double) {
        self.weightingType = type
        self.sampleRate = sampleRate
        rebuildFilter()
    }

    func updateWeighting(_ type: WeightingType) {
        guard type != weightingType else { return }
        weightingType = type
        rebuildFilter()
    }

    func process(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameLength: Int) {
        if weightingType == .z {
            output.update(from: input, count: frameLength)
            return
        }
        guard let setup = biquadSetup else {
            output.update(from: input, count: frameLength)
            return
        }

        if floatScratch.count < frameLength {
            floatScratch = [Float](repeating: 0, count: frameLength)
        }

        floatScratch.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            base.update(from: input, count: frameLength)
            vDSP_biquad(setup, &delayBuffer, base, 1, base, 1, vDSP_Length(frameLength))
            output.update(from: base, count: frameLength)
        }
    }

    private func rebuildFilter() {
        if let setup = biquadSetup {
            vDSP_biquad_DestroySetup(setup)
            biquadSetup = nil
        }
        delayBuffer = []

        guard weightingType != .z else { return }

        let coefficients = Self.coefficients(for: weightingType, sampleRate: sampleRate)
        guard !coefficients.isEmpty else { return }

        let sectionCount = vDSP_Length(coefficients.count / 5)
        biquadSetup = vDSP_biquad_CreateSetup(coefficients, sectionCount)
        delayBuffer = Array(repeating: 0, count: Int(2 * sectionCount) + 2)
    }

    deinit {
        if let setup = biquadSetup {
            vDSP_biquad_DestroySetup(setup)
        }
    }

    private static func coefficients(for type: WeightingType, sampleRate: Double) -> [Double] {
        let sections: [[(Double, Double, Double, Double, Double)]]
        switch type {
        case .a:
            sections = aWeightingSections(sampleRate: sampleRate)
        case .c:
            sections = cWeightingSections(sampleRate: sampleRate)
        case .z:
            return []
        }

        return sections.flatMap { section in
            section.flatMap { b0, b1, b2, a1, a2 in
                [b0, b1, b2, a1, a2]
            }
        }
    }

    private static func aWeightingSections(sampleRate: Double) -> [[(Double, Double, Double, Double, Double)]] {
        let f1 = 20.6, f2 = 107.7, f3 = 737.9, f4 = 12_200.0
        return [
            highPassSection(frequency: f1, sampleRate: sampleRate, q: 0.707),
            highPassSection(frequency: f2, sampleRate: sampleRate, q: 0.707),
            lowPassSection(frequency: f3, sampleRate: sampleRate, q: 0.707),
            highPassSection(frequency: f4, sampleRate: sampleRate, q: 0.707),
        ]
    }

    private static func cWeightingSections(sampleRate: Double) -> [[(Double, Double, Double, Double, Double)]] {
        let f1 = 20.6, f4 = 12_200.0
        return [
            highPassSection(frequency: f1, sampleRate: sampleRate, q: 0.707),
            lowPassSection(frequency: f4, sampleRate: sampleRate, q: 0.707),
        ]
    }

    private static func highPassSection(frequency: Double, sampleRate: Double, q: Double) -> [(Double, Double, Double, Double, Double)] {
        let w0 = 2 * Double.pi * frequency / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2 * q)

        let b0 = (1 + cosW0) / 2
        let b1 = -(1 + cosW0)
        let b2 = (1 + cosW0) / 2
        let a0 = 1 + alpha
        let a1 = -2 * cosW0
        let a2 = 1 - alpha

        return [normalizeBiquad(b0: b0, b1: b1, b2: b2, a0: a0, a1: a1, a2: a2)]
    }

    private static func lowPassSection(frequency: Double, sampleRate: Double, q: Double) -> [(Double, Double, Double, Double, Double)] {
        let w0 = 2 * Double.pi * frequency / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2 * q)

        let b0 = (1 - cosW0) / 2
        let b1 = 1 - cosW0
        let b2 = (1 - cosW0) / 2
        let a0 = 1 + alpha
        let a1 = -2 * cosW0
        let a2 = 1 - alpha

        return [normalizeBiquad(b0: b0, b1: b1, b2: b2, a0: a0, a1: a1, a2: a2)]
    }

    private static func normalizeBiquad(
        b0: Double, b1: Double, b2: Double,
        a0: Double, a1: Double, a2: Double
    ) -> (Double, Double, Double, Double, Double) {
        (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
    }
}
