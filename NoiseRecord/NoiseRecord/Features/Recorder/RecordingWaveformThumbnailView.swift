import SwiftUI

struct RecordingWaveformThumbnailView: View {
    let fileURL: URL
    var mode: AcousticMeasurementMode = .standard
    var reloadToken: Int = 0

    @State private var samples: [Float] = []

    private var minDB: Float { mode.waveformMinDB }
    private var maxDB: Float { mode.waveformMaxDB }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawWaveform(in: &context, size: size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(L10n.mediaDetailTabWaveform)
        .task(id: taskID) {
            let cached = await Task.detached(priority: .utility) {
                WaveformThumbnailCache.decibels(for: fileURL) ?? []
            }.value
            samples = cached
        }
    }

    private var taskID: String {
        "\(fileURL.path)|\(reloadToken)"
    }

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1, !samples.isEmpty else { return }

        if samples.count == 1, let sample = samples.first {
            let y = waveformYPosition(for: sample, height: size.height, minDB: minDB, maxDB: maxDB)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            let color = AcousticGaugeStyle.color(forDecibel: sample)
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
            return
        }

        let pointCount = min(samples.count, max(Int(size.width), 2))
        var points: [(CGPoint, Float)] = []
        points.reserveCapacity(pointCount)

        for pointIndex in 0..<pointCount {
            let sampleIndex = pointIndex * (samples.count - 1) / max(pointCount - 1, 1)
            let sample = samples[sampleIndex]
            let x = size.width * CGFloat(pointIndex) / CGFloat(max(pointCount - 1, 1))
            let y = waveformYPosition(for: sample, height: size.height, minDB: minDB, maxDB: maxDB)
            points.append((CGPoint(x: x, y: y), sample))
        }

        let strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
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
}
