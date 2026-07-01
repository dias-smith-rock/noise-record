import SwiftUI

struct EvidenceBarWaveformView: View {
    let samples: [Float]
    let duration: TimeInterval
    let currentTime: TimeInterval
    var mode: AcousticMeasurementMode = .standard
    var referenceLimitDB: Float = NoiseReferenceLimits.residentialNightDB
    var onSeek: ((TimeInterval) -> Void)?

    private var theme: ModeVisualTheme { .theme(for: mode) }
    private var minDB: Float { mode.waveformMinDB }
    private var maxDB: Float { mode.waveformMaxDB }

    private var shouldDrawReferenceLine: Bool {
        NoiseReferenceLimits.shouldShowReferenceLine(
            mode: mode,
            showsReferenceLimitLine: true,
            referenceDB: referenceLimitDB
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                Canvas { context, size in
                    drawWaveform(in: &context, size: size)
                    if shouldDrawReferenceLine {
                        drawReferenceLine(in: &context, size: size)
                    }
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
            .frame(height: 160)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(EvidenceTimeFormatting.playbackTime(currentTime))
                Spacer()
                Text(EvidenceTimeFormatting.remainingTime(max(0, duration - currentTime)))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1, samples.count > 1 else { return }

        let pointCount = min(samples.count, max(Int(size.width), 2))
        var points: [(CGPoint, Float)] = []
        points.reserveCapacity(pointCount)

        for pointIndex in 0..<pointCount {
            let sampleIndex = pointIndex * (samples.count - 1) / max(pointCount - 1, 1)
            let sample = samples[sampleIndex]
            let x = size.width * CGFloat(pointIndex) / CGFloat(max(pointCount - 1, 1))
            let y = yPosition(for: sample, height: size.height)
            points.append((CGPoint(x: x, y: y), sample))
        }

        let strokeStyle = StrokeStyle(
            lineWidth: theme.waveformLineWidth,
            lineCap: .round,
            lineJoin: .round
        )

        for index in 1..<points.count {
            let (startPoint, startDB) = points[index - 1]
            let (endPoint, endDB) = points[index]
            let segmentColor = AcousticGaugeStyle.color(forDecibel: (startDB + endDB) * 0.5)

            var segment = Path()
            segment.move(to: startPoint)
            segment.addLine(to: endPoint)
            context.stroke(segment, with: .color(segmentColor), style: strokeStyle)
        }
    }

    private func drawReferenceLine(in context: inout GraphicsContext, size: CGSize) {
        let y = yPosition(for: referenceLimitDB, height: size.height)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(
            path,
            with: .color(Color.secondary.opacity(0.55)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
        )
    }

    private func drawPlayhead(in context: inout GraphicsContext, size: CGSize) {
        guard duration > 0 else { return }
        let fraction = min(max(currentTime / duration, 0), 1)
        let x = CGFloat(fraction) * size.width
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(path, with: .color(.cyan.opacity(0.85)), lineWidth: 1.5)
    }

    private func yPosition(for db: Float, height: CGFloat) -> CGFloat {
        waveformYPosition(for: db, height: height, minDB: minDB, maxDB: maxDB)
    }
}
