import CoreGraphics
import UIKit

/// Shared bottom waveform strip used for burned-in video evidence and playback overlay.
enum VideoNoiseWaveformStripDrawer {
    /// Matches the ~12s rolling window used during live monitoring (`engine.history` scale).
    static let rollingSampleCapacity = 120

    /// Live camera preview overlay height (2× former 56pt).
    static let livePreviewStripHeight: CGFloat = 112

    /// Burned-in strip base height before video scale factor (2× former 120pt).
    static let burnedStripHeightPoints: CGFloat = 240

    static func rollingSamples(
        from samples: [VideoNoiseSample],
        upTo time: Double,
        capacity: Int = rollingSampleCapacity
    ) -> [VideoNoiseSample] {
        Array(samples.filter { $0.time <= time + 0.001 }.suffix(capacity))
    }

    /// Rolling waveform mapped by sample index — same semantics as live `WaveformView` during recording.
    static func drawRolling(
        in context: CGContext,
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        scale: CGFloat,
        samples: [VideoNoiseSample],
        upTo time: Double,
        mode: AcousticMeasurementMode
    ) {
        let window = rollingSamples(from: samples, upTo: time)
        guard window.count >= 2 else { return }

        let margin: CGFloat = 40 * scale
        let stripHeight = burnedStripHeightPoints * scale
        let stripRect = CGRect(
            x: margin,
            y: canvasHeight - margin - stripHeight,
            width: canvasWidth - margin * 2,
            height: stripHeight
        )

        let background = UIBezierPath(roundedRect: stripRect, cornerRadius: 14 * scale)
        UIColor.black.withAlphaComponent(0.55).setFill()
        background.fill()

        let plotInset = 16 * scale
        let plotRect = stripRect.insetBy(dx: plotInset, dy: plotInset)
        guard plotRect.width > 8, plotRect.height > 8 else { return }

        let minDB = mode.waveformMinDB
        let maxDB = mode.waveformMaxDB
        let path = UIBezierPath()

        for (index, sample) in window.enumerated() {
            let xRatio = CGFloat(index) / CGFloat(max(window.count - 1, 1))
            let clamped = min(max(sample.decibel, minDB), maxDB)
            let yRatio = CGFloat((clamped - minDB) / max(maxDB - minDB, 1))
            let point = CGPoint(
                x: plotRect.minX + plotRect.width * xRatio,
                y: plotRect.maxY - plotRect.height * yRatio
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        UIColor.systemOrange.setStroke()
        path.lineWidth = max(2.5 * scale, 2)
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18 * scale, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85),
        ]
        ("dB" as NSString).draw(
            at: CGPoint(x: stripRect.minX + 14 * scale, y: stripRect.minY + 10 * scale),
            withAttributes: labelAttributes
        )
    }

    static func decibelStrict(in samples: [VideoNoiseSample], at time: Double) -> Float? {
        guard let first = samples.first, let last = samples.last else { return nil }
        guard time >= first.time, time <= last.time else { return nil }

        if time <= first.time { return first.decibel }
        if time >= last.time { return last.decibel }

        var lower = 0
        var upper = samples.count - 1
        while lower + 1 < upper {
            let mid = (lower + upper) / 2
            if samples[mid].time <= time {
                lower = mid
            } else {
                upper = mid
            }
        }

        let start = samples[lower]
        let end = samples[upper]
        let span = end.time - start.time
        guard span > 0 else { return start.decibel }
        let progress = (time - start.time) / span
        return start.decibel + Float(progress) * (end.decibel - start.decibel)
    }
}
