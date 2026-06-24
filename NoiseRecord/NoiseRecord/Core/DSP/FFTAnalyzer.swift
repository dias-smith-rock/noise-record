import Accelerate
import Foundation

/// One FFT frame: per-bin dBFS values from DC through Nyquist (512 bins for a 1024-point real FFT).
struct FFTSpectrum: Sendable, Equatable {
    let decibels: [Float]
    let sampleRate: Double
    let fftSize: Int

    var binCount: Int { decibels.count }

    var frequencyResolution: Double {
        guard fftSize > 0 else { return 0 }
        return sampleRate / Double(fftSize)
    }

    func frequency(forBin index: Int) -> Double {
        Double(index) * frequencyResolution
    }
}

/// Real-time 1024-point Hann-windowed FFT using Accelerate/vDSP.
/// Buffers are pre-allocated and reused on every tap — no per-callback heap churn.
final class FFTAnalyzer {
    static let defaultFFTSize = 1024

    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let bufferSize: Int
    private let binCount: Int
    private let sampleRate: Double

    private var window: [Float]
    private var windowed: [Float]
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudesSquared: [Float]
    private var decibels: [Float]

    init(bufferSize: Int = FFTAnalyzer.defaultFFTSize, sampleRate: Double) {
        precondition(bufferSize > 0 && (bufferSize & (bufferSize - 1)) == 0, "FFT size must be a power of two")
        self.bufferSize = bufferSize
        self.binCount = bufferSize / 2
        self.sampleRate = sampleRate
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("vDSP_create_fftsetup failed for \(bufferSize)-point FFT")
        }
        self.fftSetup = setup

        self.window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))

        self.windowed = [Float](repeating: 0, count: bufferSize)
        self.realBuffer = [Float](repeating: 0, count: binCount)
        self.imagBuffer = [Float](repeating: 0, count: binCount)
        self.magnitudesSquared = [Float](repeating: 0, count: binCount)
        self.decibels = [Float](repeating: 0, count: binCount)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Runs window → pack → `vDSP_fft_zrip` → `vDSP_zvmags` → dBFS for one 1024-sample frame.
    func analyze(
        channelData: UnsafePointer<Float>,
        frameLength: Int,
        calibrationOffset: Float
    ) -> FFTSpectrum? {
        guard frameLength >= bufferSize else { return nil }

        // 1. Hann window
        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, vDSP_Length(bufferSize))

        return realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                // 2. Pack real signal into split-complex layout
                windowed.withUnsafeBufferPointer { input in
                    input.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: binCount) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(binCount))
                    }
                }

                // 3. Forward real FFT (Float path: vDSP_fft_zrip / vDSP_fft_zripF)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                // Normalize to preserve Parseval energy
                var scale: Float = 1.0 / Float(bufferSize)
                vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(binCount))
                vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, vDSP_Length(binCount))

                // 4. Magnitude squared → 10·log10(mag²) + calibration
                vDSP_zvmags(&split, 1, &magnitudesSquared, 1, vDSP_Length(binCount))

                var ref: Float = 1.0
                vDSP_vdbcon(magnitudesSquared, 1, &ref, &decibels, 1, vDSP_Length(binCount), 0)

                var offset = calibrationOffset
                vDSP_vsadd(decibels, 1, &offset, &decibels, 1, vDSP_Length(binCount))

                let floor: Float = -120
                var clamped = decibels
                for index in clamped.indices where !clamped[index].isFinite || clamped[index] < floor {
                    clamped[index] = floor
                }

                return FFTSpectrum(
                    decibels: clamped,
                    sampleRate: sampleRate,
                    fftSize: bufferSize
                )
            }
        }
    }
}
