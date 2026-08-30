import CoreGraphics
import UIKit

/// Builds smooth waveform polylines using sine easing between anchors
/// (linear in X / time, half-cosine ease in Y / level).
enum WaveformSinePath {
    /// Returns a denser point list suitable for stroking as a continuous curve.
    static func densify(_ anchors: [CGPoint], samplesPerSegment: Int = 12) -> [CGPoint] {
        guard anchors.count >= 2, samplesPerSegment > 0 else { return anchors }

        var result: [CGPoint] = []
        result.reserveCapacity((anchors.count - 1) * samplesPerSegment + 1)
        result.append(anchors[0])

        for index in 1..<anchors.count {
            let start = anchors[index - 1]
            let end = anchors[index]
            for step in 1...samplesPerSegment {
                let t = CGFloat(step) / CGFloat(samplesPerSegment)
                result.append(interpolated(from: start, to: end, t: t))
            }
        }
        return result
    }

    /// Densifies anchors while interpolating an associated value (e.g. dB for coloring).
    static func densify<Value>(
        _ anchors: [(CGPoint, Value)],
        samplesPerSegment: Int = 12,
        blend: (Value, Value, CGFloat) -> Value
    ) -> [(CGPoint, Value)] {
        guard anchors.count >= 2, samplesPerSegment > 0 else { return anchors }

        var result: [(CGPoint, Value)] = []
        result.reserveCapacity((anchors.count - 1) * samplesPerSegment + 1)
        result.append(anchors[0])

        for index in 1..<anchors.count {
            let start = anchors[index - 1]
            let end = anchors[index]
            for step in 1...samplesPerSegment {
                let t = CGFloat(step) / CGFloat(samplesPerSegment)
                let point = interpolated(from: start.0, to: end.0, t: t)
                let value = blend(start.1, end.1, t)
                result.append((point, value))
            }
        }
        return result
    }

    static func uiBezierPath(through anchors: [CGPoint], samplesPerSegment: Int = 12) -> UIBezierPath {
        let points = densify(anchors, samplesPerSegment: samplesPerSegment)
        let path = UIBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        return path
    }

    /// Half-cosine (sine-ease) interpolation: smooth start/stop like a sine segment.
    private static func interpolated(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let clamped = min(max(t, 0), 1)
        let sineT = (1 - cos(clamped * .pi)) * 0.5
        return CGPoint(
            x: start.x + (end.x - start.x) * clamped,
            y: start.y + (end.y - start.y) * sineT
        )
    }
}
