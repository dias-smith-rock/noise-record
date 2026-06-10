import Accelerate
import Foundation

/// Converts PCM RMS to display-ready dB SPL with low-level smoothing.
enum SPLCalculator {
    /// Supports capture down to ~-120 dBFS without log collapse.
    static let rmsFloor: Float = 0.000_001

    /// Human-audible quiet-room reference; values below blend in micro-dynamics.
    static let noiseFloorDB: Float = 20.0

    /// Recommended tap size @ 44.1/48 kHz (~23 ms refresh).
    static let tapBufferSize: UInt32 = 1024

    static func rms(from channelData: UnsafePointer<Float>, frameLength: Int) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        if rms < rmsFloor { rms = rmsFloor }
        return rms
    }

    /// dB_SPL = 20·log10(RMS) + calibrationOffset, with quiet-room floor smoothing.
    static func spl(fromRMS rms: Float, calibrationOffset: Float) -> (dbfs: Float, dbSPL: Float) {
        let clamped = max(rms, rmsFloor)
        let dbfs = 20 * log10(clamped)
        var dbSPL = dbfs + calibrationOffset

        if dbSPL < noiseFloorDB {
            // Preserve micro-dynamics instead of hard-clamping to zero.
            dbSPL = noiseFloorDB + (clamped * 100_000)
        }

        return (dbfs, dbSPL)
    }

    static func spl(
        from channelData: UnsafePointer<Float>,
        frameLength: Int,
        calibrationOffset: Float
    ) -> (rms: Float, dbfs: Float, dbSPL: Float) {
        let rms = rms(from: channelData, frameLength: frameLength)
        let converted = spl(fromRMS: rms, calibrationOffset: calibrationOffset)
        return (rms, converted.dbfs, converted.dbSPL)
    }
}
