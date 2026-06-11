import Accelerate
import Foundation

struct FFTSpectrum: Sendable {
    let magnitudes: [Float]
    let sampleRate: Double
    let binCount: Int

    var frequencyResolution: Double {
        Double(binCount * 2) > 0 ? sampleRate / Double(binCount * 2) : 0
    }

    func frequency(forBin index: Int) -> Double {
        Double(index) * frequencyResolution
    }
}

final class FFTAnalyzer {
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let bufferSize: Int
    private var window: [Float]
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudes: [Float]
    private var windowed: [Float]
    private var dbMagnitudes: [Float]
    private var displayMagnitudes: [Float]
    private let sampleRate: Double
    private let displayBinCount: Int

    init(bufferSize: Int = 2048, sampleRate: Double, displayBinCount: Int = 128) {
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        self.displayBinCount = displayBinCount
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
        self.realBuffer = [Float](repeating: 0, count: bufferSize / 2)
        self.imagBuffer = [Float](repeating: 0, count: bufferSize / 2)
        self.magnitudes = [Float](repeating: 0, count: bufferSize / 2)
        self.windowed = [Float](repeating: 0, count: bufferSize)
        self.dbMagnitudes = [Float](repeating: 0, count: bufferSize / 2)
        self.displayMagnitudes = [Float](repeating: 0, count: displayBinCount)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func analyze(channelData: UnsafePointer<Float>, frameLength: Int) -> FFTSpectrum? {
        guard frameLength >= bufferSize else { return nil }

        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, vDSP_Length(bufferSize))

        return realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { input in
                    input.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: bufferSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(bufferSize / 2))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                var scale: Float = 1.0 / Float(bufferSize)
                vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(bufferSize / 2))
                vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, vDSP_Length(bufferSize / 2))

                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))

                var ref: Float = 1.0
                vDSP_vdbcon(magnitudes, 1, &ref, &dbMagnitudes, 1, vDSP_Length(bufferSize / 2), 1)

                let copyCount = min(displayBinCount, dbMagnitudes.count)
                displayMagnitudes.withUnsafeMutableBufferPointer { dst in
                    dbMagnitudes.withUnsafeBufferPointer { src in
                        dst.baseAddress!.update(from: src.baseAddress!, count: copyCount)
                    }
                }

                return FFTSpectrum(
                    magnitudes: Array(displayMagnitudes.prefix(copyCount)),
                    sampleRate: sampleRate,
                    binCount: copyCount
                )
            }
        }
    }
}
