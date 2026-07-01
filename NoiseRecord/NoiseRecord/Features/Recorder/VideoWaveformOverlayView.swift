import SwiftUI

struct VideoWaveformOverlayView: View {
    let timeline: VideoNoiseTimeline
    let playbackDuration: TimeInterval
    let currentTime: TimeInterval
    var mode: AcousticMeasurementMode = .standard
    var onSeek: ((TimeInterval) -> Void)?

    private var theme: ModeVisualTheme { .theme(for: mode) }
    private var minDB: Float { mode.waveformMinDB }
    private var maxDB: Float { mode.waveformMaxDB }

    private var duration: TimeInterval {
        max(playbackDuration, 0.001)
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                Canvas { context, size in
                    drawWaveform(in: &context, size: size)
                    drawPlayhead(in: &context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0 else { return }
                            let fraction = min(max(value.location.x / geometry.size.width, 0), 1)
                            onSeek?(fraction * duration)
                        }
                )
            }
            .frame(height: 56)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(EvidenceTimeFormatting.playbackTime(currentTime))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel(L10n.mediaDetailTabWaveform)
    }

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1, timeline.samples.count > 1, duration > 0 else { return }

        let pointCount = min(max(Int(size.width), 2), 256)
        var points: [(CGPoint, Float)] = []
        points.reserveCapacity(pointCount)

        for pointIndex in 0..<pointCount {
            let time = duration * Double(pointIndex) / Double(max(pointCount - 1, 1))
            guard let db = timeline.decibelStrict(at: time) else { continue }
            let x = CGFloat(time / duration) * size.width
            let y = waveformYPosition(for: db, height: size.height, minDB: minDB, maxDB: maxDB)
            points.append((CGPoint(x: x, y: y), db))
        }

        guard points.count > 1 else { return }

        let strokeStyle = StrokeStyle(
            lineWidth: theme.waveformLineWidth,
            lineCap: .round,
            lineJoin: .round
        )

        var previousPoint: (CGPoint, Float)?
        for point in points {
            guard let previous = previousPoint else {
                previousPoint = point
                continue
            }
            let segmentColor = AcousticGaugeStyle.color(forDecibel: (previous.1 + point.1) * 0.5)
            var segment = Path()
            segment.move(to: previous.0)
            segment.addLine(to: point.0)
            context.stroke(segment, with: .color(segmentColor), style: strokeStyle)
            previousPoint = point
        }
    }

    private func drawPlayhead(in context: inout GraphicsContext, size: CGSize) {
        guard duration > 0 else { return }
        let fraction = min(max(currentTime / duration, 0), 1)
        let x = CGFloat(fraction) * size.width
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(path, with: .color(.cyan.opacity(0.9)), lineWidth: 1.5)
    }
}
