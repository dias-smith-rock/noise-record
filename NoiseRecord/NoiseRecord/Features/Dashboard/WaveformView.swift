import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    var minDB: Float = 20
    var maxDB: Float = 100

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let count = max(samples.count, 1)

            Path { path in
                guard !samples.isEmpty else { return }
                for (index, sample) in samples.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(count - 1)
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
                    colors: [.green, .yellow, .orange, .red],
                    startPoint: .bottom,
                    endPoint: .top
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SpectrumView: View {
    let spectrum: FFTSpectrum?

    var body: some View {
        GeometryReader { geometry in
            if let spectrum, !spectrum.magnitudes.isEmpty {
                let bins = spectrum.magnitudes.prefix(128)
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(bins.enumerated()), id: \.offset) { _, magnitude in
                        let normalized = CGFloat((magnitude + 80) / 80)
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.8))
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
