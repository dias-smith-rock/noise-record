import Accelerate
import Foundation

/// One FFT frame: per-bin dBFS values from DC through Nyquist.
struct FFTSpectrum: Sendable, Equatable {
  let decibels: [Float]
  let peakDecibels: [Float]
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

  init(
    decibels: [Float],
    sampleRate: Double,
    fftSize: Int,
    peakDecibels: [Float] = []
  ) {
    self.decibels = decibels
    self.peakDecibels = peakDecibels
    self.sampleRate = sampleRate
    self.fftSize = fftSize
  }
}

/// Hann-windowed real FFT using Accelerate/vDSP.
/// Both 1024- and 2048-point setups, Hann windows, and scratch buffers are pre-allocated.
final class FFTAnalyzer {
  static let defaultFFTSize = FFTConfiguration.standard.fftSize

  private let sampleRate: Double
  private var activeConfiguration: FFTConfiguration

  private let standardSetup: FFTSetup
  private let advancedSetup: FFTSetup

  private let hannStandard: [Float]
  private let hannAdvanced: [Float]

  private var windowed: [Float]
  private var realBuffer: [Float]
  private var imagBuffer: [Float]
  private var magnitudesSquared: [Float]
  private var decibels: [Float]
  private var spectrumOutput: [Float]

  private var activeBufferSize: Int { activeConfiguration.fftSize }
  private var activeBinCount: Int { activeConfiguration.binCount }
  private var activeLog2n: vDSP_Length { activeConfiguration.log2n }

  private var activeSetup: FFTSetup {
    activeConfiguration == .advanced ? advancedSetup : standardSetup
  }

  init(
    sampleRate: Double,
    configuration: FFTConfiguration = .standard
  ) {
    precondition(
      FFTConfiguration.standard.fftSize > 0 && FFTConfiguration.advanced.fftSize > 0,
      "FFT sizes must be positive"
    )

    self.sampleRate = sampleRate
    self.activeConfiguration = configuration

    guard let standard = Self.makeFFTSetup(for: .standard) else {
      fatalError("vDSP_create_fftsetup failed for 1024-point FFT")
    }
    guard let advanced = Self.makeFFTSetup(for: .advanced) else {
      fatalError("vDSP_create_fftsetup failed for 2048-point FFT")
    }
    self.standardSetup = standard
    self.advancedSetup = advanced

    self.hannStandard = Self.makeHannWindow(size: FFTConfiguration.standard.fftSize)
    self.hannAdvanced = Self.makeHannWindow(size: FFTConfiguration.advanced.fftSize)

    let maxBins = FFTConfiguration.advanced.binCount
    self.windowed = [Float](repeating: 0, count: FFTConfiguration.advanced.fftSize)
    self.realBuffer = [Float](repeating: 0, count: maxBins)
    self.imagBuffer = [Float](repeating: 0, count: maxBins)
    self.magnitudesSquared = [Float](repeating: 0, count: maxBins)
    self.decibels = [Float](repeating: 0, count: maxBins)
    self.spectrumOutput = [Float](repeating: SpectrumDSPGuards.analyzerDecibelFloor, count: maxBins)
  }

  convenience init(bufferSize: Int, sampleRate: Double) {
    let configuration = FFTConfiguration(rawValue: bufferSize) ?? .standard
    self.init(sampleRate: sampleRate, configuration: configuration)
  }

  deinit {
    vDSP_destroy_fftsetup(standardSetup)
    vDSP_destroy_fftsetup(advancedSetup)
  }

  var activeFFTSize: Int { activeBufferSize }

  func reconfigure(to configuration: FFTConfiguration) {
    activeConfiguration = configuration
  }

  /// Runs window → pack → `vDSP_fft_zrip` → `vDSP_zvmags` → dBFS for one frame.
  func analyze(
    channelData: UnsafePointer<Float>,
    frameLength: Int,
    calibrationOffset: Float
  ) -> FFTSpectrum? {
    let bufferSize = activeBufferSize
    let binCount = activeBinCount
    guard frameLength >= bufferSize else { return nil }

    let hann: UnsafePointer<Float>
    switch activeConfiguration {
    case .standard:
      hann = hannStandard.withUnsafeBufferPointer { $0.baseAddress! }
    case .advanced:
      hann = hannAdvanced.withUnsafeBufferPointer { $0.baseAddress! }
    }

    let length = vDSP_Length(bufferSize)
    let binLength = vDSP_Length(binCount)

    // 1. Hann window (in-place into pre-allocated `windowed` prefix)
    vDSP_vmul(channelData, 1, hann, 1, &windowed, 1, length)

    return realBuffer.withUnsafeMutableBufferPointer { realPtr in
      imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
        guard let realBase = realPtr.baseAddress, let imagBase = imagPtr.baseAddress else {
          return nil
        }
        var split = DSPSplitComplex(realp: realBase, imagp: imagBase)

        // 2. Pack real signal into split-complex layout
        windowed.withUnsafeBufferPointer { input in
          input.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: binCount) { complexPtr in
            vDSP_ctoz(complexPtr, 2, &split, 1, binLength)
          }
        }

        // 3. Forward real FFT
        vDSP_fft_zrip(activeSetup, &split, 1, activeLog2n, FFTDirection(FFT_FORWARD))

        var scale: Float = 1.0 / Float(bufferSize)
        vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, binLength)
        vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, binLength)

        // 4. Magnitude² → dBFS
        vDSP_zvmags(&split, 1, &magnitudesSquared, 1, binLength)

        var ref: Float = 1.0
        vDSP_vdbcon(magnitudesSquared, 1, &ref, &decibels, 1, binLength, 0)

        let floor = SpectrumDSPGuards.analyzerDecibelFloor
        replaceNonFiniteDecibels(in: &decibels, count: binCount, floor: floor)

        var offset = calibrationOffset
        vDSP_vsadd(decibels, 1, &offset, &decibels, 1, binLength)

        replaceNonFiniteDecibels(in: &decibels, count: binCount, floor: floor)

        // Suppress DC only; preserve low-frequency resonance bins.
        let dcEnd = min(SpectrumDSPGuards.dcSuppressBinCount, binCount)
        if dcEnd > 0 {
          var dcFloor = floor
          vDSP_vfill(&dcFloor, &decibels, 1, vDSP_Length(dcEnd))
        }

        if spectrumOutput.count != binCount {
          spectrumOutput = [Float](repeating: floor, count: binCount)
        }
        decibels.withUnsafeBufferPointer { source in
          spectrumOutput.withUnsafeMutableBufferPointer { destination in
            guard let src = source.baseAddress, let dst = destination.baseAddress else { return }
            memcpy(dst, src, binCount * MemoryLayout<Float>.size)
          }
        }

        return FFTSpectrum(
          decibels: spectrumOutput,
          sampleRate: sampleRate,
          fftSize: bufferSize
        )
      }
    }
  }

  private static func makeFFTSetup(for configuration: FFTConfiguration) -> FFTSetup? {
    vDSP_create_fftsetup(configuration.log2n, FFTRadix(kFFTRadix2))
  }

  private static func makeHannWindow(size: Int) -> [Float] {
    var window = [Float](repeating: 0, count: size)
    vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
    return window
  }

  private func replaceNonFiniteDecibels(in values: inout [Float], count: Int, floor: Float) {
    values.withUnsafeMutableBufferPointer { buffer in
      guard let base = buffer.baseAddress else { return }
      for index in 0..<count where !base[index].isFinite {
        base[index] = floor
      }
    }
  }
}
