import SwiftUI

struct RecordingWaveformThumbnailView: View {
    let fileURL: URL
    var mode: AcousticMeasurementMode = .standard
    var reloadToken: Int = 0

    @State private var timeline: VideoNoiseTimeline?
    @State private var playbackDuration: TimeInterval = 0

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
            let data = await Task.detached(priority: .utility) {
                WaveformThumbnailCache.thumbnail(for: fileURL)
            }.value
            timeline = data?.timeline
            playbackDuration = data?.playbackDuration ?? 0
        }
    }

    private var taskID: String {
        "\(fileURL.path)|\(reloadToken)"
    }

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1,
              let timeline, timeline.samples.count > 1,
              playbackDuration > 0 else { return }

        let duration = playbackDuration
        let pointCount = min(max(Int(size.width), 2), 120)
        var points: [(CGPoint, Float)] = []
        points.reserveCapacity(pointCount)

        for pointIndex in 0..<pointCount {
            let time = duration * Double(pointIndex) / Double(max(pointCount - 1, 1))
            guard let db = timeline.decibel(at: time) else { continue }
            let x = CGFloat(time / duration) * size.width
            let y = waveformYPosition(for: db, height: size.height, minDB: minDB, maxDB: maxDB)
            points.append((CGPoint(x: x, y: y), db))
        }

        guard points.count > 1 else { return }

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
