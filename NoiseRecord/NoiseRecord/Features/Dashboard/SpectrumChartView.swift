import SwiftUI

// MARK: - 坐标系

/// 频谱图统一坐标映射：X 为对数频率，Y 为线性分贝。
/// 网格线与数据曲线共用同一套公式，保证物理对齐。
private struct SpectrumPlotCoordinateSystem: Sendable {
    let plotRect: CGRect

    /// 横轴下界：20 Hz（人耳可闻低频端）
    let minFrequency: Double = 20
    /// 横轴上界：22050 Hz（44100 Hz 采样率的 Nyquist 频率）
    let maxFrequency: Double = 22_050
    /// 纵轴下界：-20 dB
    let minDecibels: Double = -20
    /// 纵轴上界：100 dB
    let maxDecibels: Double = 100

    private var logMin: Double { safeLog10(minFrequency) }
    private var logMax: Double { safeLog10(maxFrequency) }
    private var logSpan: Double { max(logMax - logMin, 1e-9) }
    private var decibelSpan: Double { max(maxDecibels - minDecibels, 1e-9) }

    /// 对数频率 → X 像素。
    /// x = (log₁₀(f) − log₁₀(20)) / (log₁₀(22050) − log₁₀(20)) × width
    func x(forFrequency hz: Double) -> CGFloat {
        guard plotRect.width > 0 else { return plotRect.minX }
        let clamped = min(max(hz, minFrequency), maxFrequency)
        let normalized = (safeLog10(clamped) - logMin) / logSpan
        guard normalized.isFinite else { return plotRect.minX }
        return plotRect.minX + CGFloat(normalized) * plotRect.width
    }

    /// 第 i 个 FFT Bin → 物理频率 → X 像素。
    /// f = i × (sampleRate / fftSize)，例如 44100/1024 ≈ 43.066 Hz/Bin。
    func x(forBin bin: Int, sampleRate: Double, fftSize: Int) -> CGFloat {
        guard fftSize > 0, bin >= 0 else { return plotRect.minX }
        let frequency = Double(bin) * sampleRate / Double(fftSize)
        return x(forFrequency: frequency)
    }

    /// 线性分贝 → Y 像素（顶部为高声压，底部为低声压）。
    /// y = (1 − (dB − (−20)) / (100 − (−20))) × height
    func y(forDecibels db: Float) -> CGFloat {
        guard plotRect.height > 0 else { return plotRect.midY }
        let clamped = min(max(Double(db), minDecibels), maxDecibels)
        let normalized = 1.0 - (clamped - minDecibels) / decibelSpan
        guard normalized.isFinite else { return plotRect.midY }
        return plotRect.minY + CGFloat(normalized) * plotRect.height
    }

    private func safeLog10(_ value: Double) -> Double {
        guard value > 0 else { return logMin }
        let result = log10(value)
        return result.isFinite ? result : logMin
    }
}

// MARK: - 主视图

/// 专业双线 RTA：对数频率轴 + 线性分贝轴 + 网格刻度 + 实时/峰值保持曲线。
struct SpectrumChartView: View, Equatable {
    let spectrum: FFTSpectrum?
    var isActive: Bool = true

    @State private var peakDecibels: [Float] = []

    private static let plotInsets = EdgeInsets(top: 14, leading: 34, bottom: 8, trailing: 10)
    private static let noiseFloor: Float = -120
    private static let peakDecayRate: Float = 10

    private static let frequencyGridHz: [Double] = [62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    private static let decibelGridValues: [Int] = [0, 20, 40, 60, 80, 100]

    static func == (lhs: SpectrumChartView, rhs: SpectrumChartView) -> Bool {
        lhs.isActive == rhs.isActive && lhs.spectrum == rhs.spectrum
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let plotRect = plotRect(in: size)
                let coords = SpectrumPlotCoordinateSystem(plotRect: plotRect)

                drawFrequencyGrid(context: &context, coords: coords)
                drawDecibelGrid(context: &context, coords: coords)

                if let spectrum, !spectrum.decibels.isEmpty {
                    drawLiveSpectrum(context: &context, coords: coords, spectrum: spectrum)
                    drawPeakHoldSpectrum(context: &context, coords: coords, spectrum: spectrum)
                    drawPeakMarker(context: &context, coords: coords, spectrum: spectrum)
                }
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
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .drawingGroup()
        .onChange(of: spectrum) { _, newValue in
            capturePeaks(from: newValue)
        }
        .onChange(of: isActive) { _, active in
            if !active { resetPeaks() }
        }
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled, isActive {
                try? await Task.sleep(for: .milliseconds(33))
                decayPeaks(elapsed: 1.0 / 30.0)
            }
        }
    }

    // MARK: - 布局

    /// 扣除轴标签留白后的绘图区（约 12–15 pt 边距，防止文字被圆角卡片裁切）。
    private func plotRect(in size: CGSize) -> CGRect {
        let insets = Self.plotInsets
        let width = max(size.width - insets.leading - insets.trailing, 1)
        let height = max(size.height - insets.top - insets.bottom, 1)
        return CGRect(x: insets.leading, y: insets.top, width: width, height: height)
    }

    // MARK: - 网格与刻度

    private func drawFrequencyGrid(context: inout GraphicsContext, coords: SpectrumPlotCoordinateSystem) {
        let dashStyle = StrokeStyle(lineWidth: 0.5, dash: [2, 4])

        for hz in Self.frequencyGridHz {
            let x = coords.x(forFrequency: hz)
            var line = Path()
            line.move(to: CGPoint(x: x, y: coords.plotRect.minY))
            line.addLine(to: CGPoint(x: x, y: coords.plotRect.maxY))
            context.stroke(line, with: .color(.gray.opacity(0.15)), style: dashStyle)

            let label = Self.formatGridFrequency(hz)
            let resolved = context.resolve(
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.55))
            )
            context.draw(
                resolved,
                at: CGPoint(x: x, y: coords.plotRect.minY - 2),
                anchor: .bottom
            )
        }
    }

    private func drawDecibelGrid(context: inout GraphicsContext, coords: SpectrumPlotCoordinateSystem) {
        let lineStyle = StrokeStyle(lineWidth: 0.5, dash: [3, 3])

        for db in Self.decibelGridValues {
            let y = coords.y(forDecibels: Float(db))
            var line = Path()
            line.move(to: CGPoint(x: coords.plotRect.minX, y: y))
            line.addLine(to: CGPoint(x: coords.plotRect.maxX, y: y))
            context.stroke(line, with: .color(.gray.opacity(0.12)), style: lineStyle)

            let resolved = context.resolve(
                Text("\(db)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.gray.opacity(0.55))
            )
            context.draw(
                resolved,
                at: CGPoint(x: coords.plotRect.minX - 4, y: y),
                anchor: .trailing
            )
        }
    }

    // MARK: - 数据曲线

    private func drawLiveSpectrum(
        context: inout GraphicsContext,
        coords: SpectrumPlotCoordinateSystem,
        spectrum: FFTSpectrum
    ) {
        let path = spectrumPath(
            decibels: spectrum.decibels,
            coords: coords,
            sampleRate: spectrum.sampleRate,
            fftSize: spectrum.fftSize
        )
        context.stroke(
            path,
            with: .color(.green),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawPeakHoldSpectrum(
        context: inout GraphicsContext,
        coords: SpectrumPlotCoordinateSystem,
        spectrum: FFTSpectrum
    ) {
        guard peakDecibels.count == spectrum.decibels.count else { return }

        let path = spectrumPath(
            decibels: peakDecibels,
            coords: coords,
            sampleRate: spectrum.sampleRate,
            fftSize: spectrum.fftSize
        )
        context.stroke(
            path,
            with: .color(.pink),
            style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
        )
    }

    /// 遍历 Bin 1…511，先算物理频率再映射 X，保证曲线与网格绝对对齐。
    private func spectrumPath(
        decibels: [Float],
        coords: SpectrumPlotCoordinateSystem,
        sampleRate: Double,
        fftSize: Int
    ) -> Path {
        var path = Path()
        let maxBin = min(decibels.count, fftSize / 2)
        guard maxBin > 1 else { return path }

        for bin in 1..<maxBin {
            let point = CGPoint(
                x: coords.x(forBin: bin, sampleRate: sampleRate, fftSize: fftSize),
                y: coords.y(forDecibels: decibels[bin])
            )
            if bin == 1 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    // MARK: - 峰值标注

    private func drawPeakMarker(
        context: inout GraphicsContext,
        coords: SpectrumPlotCoordinateSystem,
        spectrum: FFTSpectrum
    ) {
        guard peakDecibels.count == spectrum.decibels.count else { return }

        // 在峰值保持曲线上找全局最大 Bin
        guard let peakBin = peakDecibels.enumerated().max(by: { $0.element < $1.element })?.offset,
              peakDecibels[peakBin] > Float(coords.minDecibels) + 4 else { return }

        let peakDB = peakDecibels[peakBin]
        let peakFrequency = Double(peakBin) * spectrum.sampleRate / Double(spectrum.fftSize)
        let anchor = CGPoint(
            x: coords.x(forBin: peakBin, sampleRate: spectrum.sampleRate, fftSize: spectrum.fftSize),
            y: coords.y(forDecibels: peakDB)
        )

        // 3 px 实心顶点
        let dotRect = CGRect(x: anchor.x - 1.5, y: anchor.y - 1.5, width: 3, height: 3)
        context.fill(Path(ellipseIn: dotRect), with: .color(.pink))

        let label = Self.formatPeakFrequency(peakFrequency)
        let resolved = context.resolve(
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.95))
        )
        context.draw(resolved, at: CGPoint(x: anchor.x, y: anchor.y - 5), anchor: .bottom)
    }

    // MARK: - 峰值保持

    private func capturePeaks(from spectrum: FFTSpectrum?) {
        guard let spectrum, !spectrum.decibels.isEmpty else { return }
        ensurePeakCapacity(spectrum.decibels.count)
        for index in spectrum.decibels.indices {
            peakDecibels[index] = max(peakDecibels[index], spectrum.decibels[index])
        }
    }

    private func decayPeaks(elapsed: TimeInterval) {
        guard !peakDecibels.isEmpty else { return }
        let decay = Float(elapsed) * Self.peakDecayRate
        for index in peakDecibels.indices {
            var value = peakDecibels[index] - decay
            if value < Self.noiseFloor { value = Self.noiseFloor }
            peakDecibels[index] = value
        }
        if let spectrum { capturePeaks(from: spectrum) }
    }

    private func resetPeaks() {
        let capacity = FFTAnalyzer.defaultFFTSize / 2
        if peakDecibels.count != capacity {
            peakDecibels = [Float](repeating: Self.noiseFloor, count: capacity)
        } else {
            for index in peakDecibels.indices {
                peakDecibels[index] = Self.noiseFloor
            }
        }
    }

    private func ensurePeakCapacity(_ count: Int) {
        guard peakDecibels.count != count else { return }
        peakDecibels = [Float](repeating: Self.noiseFloor, count: count)
    }

    // MARK: - 标签格式化

    private static func formatGridFrequency(_ hz: Double) -> String {
        switch hz {
        case 1_000...: return String(format: "%.0fK", hz / 1000)
        default: return String(format: "%.0f Hz", hz)
        }
    }

    private static func formatPeakFrequency(_ hz: Double) -> String {
        guard hz.isFinite, hz > 0 else { return "— Hz" }
        if hz >= 10_000 { return String(format: "%.0f Hz", hz) }
        if hz >= 1_000 { return String(format: "%.1f kHz", hz / 1000) }
        return String(format: "%.0f Hz", hz)
    }
}
