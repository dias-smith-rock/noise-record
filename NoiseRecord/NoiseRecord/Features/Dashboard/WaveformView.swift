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

            ZStack {
                if mode.isHighSensitivity {
                    highSensitivityGrid(in: geometry.size)
                }

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
                    LinearGradient(
                        colors: theme.waveformGradient,
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(
                        lineWidth: theme.waveformLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .shadow(color: mode.isHighSensitivity ? theme.accent.opacity(0.45) : .clear, radius: 4)

                if mode.isHighSensitivity && !samples.isEmpty {
                    highSensitivitySparkles(width: width, height: height, count: count)
                }
            }
        }
        .background(
            mode.isHighSensitivity
                ? theme.cardTint
                : Color(.secondarySystemBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    mode.isHighSensitivity ? theme.accent.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func highSensitivityGrid(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let step: CGFloat = 16
            var path = Path()
            stride(from: 0, through: canvasSize.width, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }
            stride(from: 0, through: canvasSize.height, by: step).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
            context.stroke(path, with: .color(theme.secondaryAccent.opacity(0.12)), lineWidth: 0.5)
        }
        .frame(width: size.width, height: size.height)
    }

    private func highSensitivitySparkles(width: CGFloat, height: CGFloat, count: Int) -> some View {
        let recent = samples.suffix(min(12, samples.count))
        return ZStack {
            ForEach(Array(recent.enumerated()), id: \.offset) { index, sample in
                let globalIndex = samples.count - recent.count + index
                let x = width * CGFloat(globalIndex) / CGFloat(max(count - 1, 1))
                let normalized = CGFloat((sample - minDB) / max(maxDB - minDB, 1))
                let y = height * (1 - min(max(normalized, 0), 1))
                Circle()
                    .fill(theme.accent.opacity(0.7))
                    .frame(width: 3, height: 3)
                    .position(x: x, y: y)
                    .blur(radius: 0.5)
            }
        }
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
                    ForEach(Array(bins.enumerated()), id: \.offset) { index, magnitude in
                        let normalized = CGFloat((magnitude + 80) / 80)
                        let barColor = theme.waveformGradient[index % theme.waveformGradient.count]
                        Rectangle()
                            .fill(barColor.opacity(mode.isHighSensitivity ? 0.95 : 0.8))
                            .frame(height: geometry.size.height * min(max(normalized, 0.02), 1))
                    }
                }
            } else {
                Text("频谱数据加载中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            mode.isHighSensitivity
                ? theme.cardTint
                : Color(.secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
