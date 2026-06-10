import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    var mode: AcousticMeasurementMode = .standard
    var minDB: Float = 20
    var maxDB: Float = 100

    private var theme: ModeVisualTheme { .theme(for: mode) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let count = max(samples.count, 1)

            Path { path in
                guard !samples.isEmpty else { return }
                for (index, sample) in samples.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(max(count - 1, 1))
                    let normalized = CGFloat((sample - minDB) / max(maxDB - minDB, 1))
                    let y = height * (1 - min(max(normalized, 0), 1))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                theme.accent,
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
    }
}

struct SpectrumView: View {
    let spectrum: FFTSpectrum?
    var mode: AcousticMeasurementMode = .standard

    private var theme: ModeVisualTheme { .theme(for: mode) }

    var body: some View {
        GeometryReader { geometry in
            if let spectrum, !spectrum.magnitudes.isEmpty {
                let bins = spectrum.magnitudes.prefix(128)
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(bins.enumerated()), id: \.offset) { _, magnitude in
                        let normalized = CGFloat((magnitude + 80) / 80)
                        let clamped = min(max(normalized, 0.02), 1)
                        Rectangle()
                            .fill(theme.accent.opacity(0.2 + 0.75 * clamped))
                            .frame(height: geometry.size.height * clamped)
                    }
                }
            } else {
                Text(L10n.spectrumLoading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
