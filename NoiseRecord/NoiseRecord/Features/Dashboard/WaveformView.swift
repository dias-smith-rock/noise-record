import SwiftUI

struct WaveformView: View, Equatable {
    let samples: [Float]
    var mode: AcousticMeasurementMode = .standard
    var usesCardChrome: Bool = true
    var showsYAxisLabels: Bool = true
    var showsReferenceLimitLine: Bool = true
    var referenceLimitDB: Float = NoiseReferenceLimits.residentialNightDB
    var axisLabelColor: Color = .secondary

    private var theme: ModeVisualTheme { .theme(for: mode) }
    private var minDB: Float { mode.waveformMinDB }
    private var maxDB: Float { mode.waveformMaxDB }

    private var shouldDrawReferenceLine: Bool {
        NoiseReferenceLimits.shouldShowReferenceLine(
            mode: mode,
            showsReferenceLimitLine: showsReferenceLimitLine,
            referenceDB: referenceLimitDB
        )
    }

    static func == (lhs: WaveformView, rhs: WaveformView) -> Bool {
        lhs.samples.count == rhs.samples.count
            && lhs.samples.last == rhs.samples.last
            && lhs.mode == rhs.mode
            && lhs.usesCardChrome == rhs.usesCardChrome
            && lhs.showsYAxisLabels == rhs.showsYAxisLabels
            && lhs.showsReferenceLimitLine == rhs.showsReferenceLimitLine
            && lhs.referenceLimitDB == rhs.referenceLimitDB
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if showsYAxisLabels {
                yAxisLabels
                    .frame(width: 30, alignment: .trailing)
            }

            waveformCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var yAxisLabels: some View {
        VStack(spacing: 0) {
            Text(formatAxisLabel(maxDB))
            Spacer(minLength: 0)
            Text(formatAxisLabel(minDB))
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(axisLabelColor)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private var waveformCanvas: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }

            if showsYAxisLabels {
                drawYAxisGrid(in: &context, size: size)
            }

            if shouldDrawReferenceLine {
                drawReferenceLimitLine(in: &context, size: size)
            }

            guard samples.count > 1 else { return }

            let points = resampledPoints(samples: samples, size: size, minDB: minDB, maxDB: maxDB)
            guard points.count > 1 else { return }

            let strokeStyle = StrokeStyle(
                lineWidth: usesCardChrome ? theme.waveformLineWidth : 2,
                lineCap: .round,
                lineJoin: .round
            )

            for index in 1..<points.count {
                let (startPoint, startDB) = points[index - 1]
                let (endPoint, endDB) = points[index]
                let segmentColor = AcousticGaugeStyle.color(
                    forDecibel: (startDB + endDB) * 0.5
                )

                var segment = Path()
                segment.move(to: startPoint)
                segment.addLine(to: endPoint)
                context.stroke(segment, with: .color(segmentColor), style: strokeStyle)
            }
        }
        .background(usesCardChrome ? AnyShapeStyle(Color(.secondarySystemGroupedBackground)) : AnyShapeStyle(Color.clear))
        .overlay {
            if usesCardChrome {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.surfaceBorder, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: usesCardChrome ? 12 : 0))
        .drawingGroup()
    }

    private func drawReferenceLimitLine(in context: inout GraphicsContext, size: CGSize) {
        let lineColor = axisLabelColor.opacity(0.55)
        let y = waveformYPosition(for: referenceLimitDB, height: size.height, minDB: minDB, maxDB: maxDB)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(
            path,
            with: .color(lineColor),
            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
        )

        let label = Text(formatReferenceLimitLabel(referenceLimitDB))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(lineColor)
        context.draw(label, at: CGPoint(x: size.width - 2, y: y - 6), anchor: .bottomTrailing)
    }

    private func formatReferenceLimitLabel(_ db: Float) -> String {
        "\(Int(db.rounded())) dB"
    }

    private func drawYAxisGrid(in context: inout GraphicsContext, size: CGSize) {
        let gridColor = axisLabelColor.opacity(0.22)
        let gridStyle = StrokeStyle(lineWidth: 0.5, dash: [4, 4])

        for db in [minDB, maxDB] {
            let y = waveformYPosition(for: db, height: size.height, minDB: minDB, maxDB: maxDB)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), style: gridStyle)
        }
    }

    private func formatAxisLabel(_ db: Float) -> String {
        String(Int(db.rounded()))
    }
}

// MARK: - Sampling

func waveformYPosition(for db: Float, height: CGFloat, minDB: Float, maxDB: Float) -> CGFloat {
    let dbRange = max(maxDB - minDB, 1)
    let normalized = CGFloat((db - minDB) / dbRange)
    return height * (1 - min(max(normalized, 0), 1))
}

private func resampledPoints(
    samples: [Float],
    size: CGSize,
    minDB: Float,
    maxDB: Float
) -> [(CGPoint, Float)] {
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

    return points
}

struct SpectrumView: View, Equatable {
    let spectrum: FFTSpectrum?
    var mode: AcousticMeasurementMode = .standard

    private var theme: ModeVisualTheme { .theme(for: mode) }

    static func == (lhs: SpectrumView, rhs: SpectrumView) -> Bool {
        guard lhs.mode == rhs.mode else { return false }
        switch (lhs.spectrum, rhs.spectrum) {
        case (nil, nil): return true
        case let (left?, right?):
            guard left.decibels.count == right.decibels.count else { return false }
            return zip(left.decibels, right.decibels).allSatisfy { abs($0 - $1) < 0.25 }
        default:
            return false
        }
    }

    var body: some View {
        Canvas { context, size in
            guard let spectrum, !spectrum.decibels.isEmpty, size.width > 1, size.height > 1 else {
                return
            }

            let bins = min(spectrum.decibels.count, 128)
            let barWidth = size.width / CGFloat(bins)

            for index in 0..<bins {
                let db = spectrum.decibels[index]
                let normalized = CGFloat((db - (-80)) / 80)
                let clamped = min(max(normalized, 0.02), 1)
                let height = size.height * clamped
                let rect = CGRect(
                    x: CGFloat(index) * barWidth,
                    y: size.height - height,
                    width: max(barWidth - 1, 1),
                    height: height
                )
                context.fill(
                    Path(rect),
                    with: .color(theme.accent.opacity(0.2 + 0.75 * clamped))
                )
            }
        }
        .overlay {
            if spectrum == nil || spectrum?.decibels.isEmpty == true {
                Text(L10n.spectrumLoading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .drawingGroup()
    }
}
