import SwiftUI

struct WaveformView: View, Equatable {
    let samples: [Float]
    var mode: AcousticMeasurementMode = .standard
    var minDB: Float = 20
    var maxDB: Float = 100

    private var theme: ModeVisualTheme { .theme(for: mode) }

    static func == (lhs: WaveformView, rhs: WaveformView) -> Bool {
        lhs.samples.count == rhs.samples.count
            && lhs.samples.last == rhs.samples.last
            && lhs.mode == rhs.mode
            && lhs.minDB == rhs.minDB
            && lhs.maxDB == rhs.maxDB
    }

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1, size.width > 1, size.height > 1 else { return }

            let pointCount = min(samples.count, max(Int(size.width), 2))
            let dbRange = max(maxDB - minDB, 1)
            var path = Path()

            for pointIndex in 0..<pointCount {
                let sampleIndex = pointIndex * (samples.count - 1) / max(pointCount - 1, 1)
                let sample = samples[sampleIndex]
                let x = size.width * CGFloat(pointIndex) / CGFloat(max(pointCount - 1, 1))
                let normalized = CGFloat((sample - minDB) / dbRange)
                let y = size.height * (1 - min(max(normalized, 0), 1))
                let point = CGPoint(x: x, y: y)
                if pointIndex == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(
                path,
                with: .color(theme.accent),
                style: StrokeStyle(
                    lineWidth: theme.waveformLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
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

struct SpectrumView: View, Equatable {
    let spectrum: FFTSpectrum?
    var mode: AcousticMeasurementMode = .standard

    private var theme: ModeVisualTheme { .theme(for: mode) }

    static func == (lhs: SpectrumView, rhs: SpectrumView) -> Bool {
        guard lhs.mode == rhs.mode else { return false }
        switch (lhs.spectrum, rhs.spectrum) {
        case (nil, nil): return true
        case let (left?, right?):
            guard left.magnitudes.count == right.magnitudes.count else { return false }
            return zip(left.magnitudes, right.magnitudes).allSatisfy { abs($0 - $1) < 0.25 }
        default:
            return false
        }
    }

    var body: some View {
        Canvas { context, size in
            guard let spectrum, !spectrum.magnitudes.isEmpty, size.width > 1, size.height > 1 else {
                return
            }

            let bins = min(spectrum.magnitudes.count, 128)
            let barWidth = size.width / CGFloat(bins)

            for index in 0..<bins {
                let magnitude = spectrum.magnitudes[index]
                let normalized = CGFloat((magnitude + 80) / 80)
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
            if spectrum == nil || spectrum?.magnitudes.isEmpty == true {
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
