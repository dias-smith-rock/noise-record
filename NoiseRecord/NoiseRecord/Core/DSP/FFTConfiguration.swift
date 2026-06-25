import Accelerate
import Foundation

/// Selectable real-FFT frame length for the spectrum pipeline.
enum FFTConfiguration: Int, Sendable, Equatable {
  case standard = 1024
  case advanced = 2048

  var fftSize: Int { rawValue }

  /// Usable one-sided spectrum bins (DC … Nyquist).
  var binCount: Int { rawValue / 2 }

  /// $ \log_2(N) $ for vDSP real FFT setup.
  var log2n: vDSP_Length { vDSP_Length(log2(Float(rawValue))) }

  /// Bin spacing in Hz at 44.1 kHz (e.g. 43.07 Hz @ 1024, 21.53 Hz @ 2048).
  var frequencyResolutionAt44_1kHz: Double { 44_100 / Double(rawValue) }

  static func forHighSensitivityMode(_ highSensitivity: Bool) -> FFTConfiguration {
    highSensitivity ? .advanced : .standard
  }
}
