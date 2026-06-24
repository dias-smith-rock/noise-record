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
    /// 纵轴下界：-20 dBA
    var minDecibels: Double { Double(SpectrumDSPGuards.plotDecibelMin) }
    /// 纵轴上界：120 dBA
    var maxDecibels: Double { Double(SpectrumDSPGuards.plotDecibelMax) }

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
    /// f = i × (sampleRate / fftSize)；强制 f ≥ 20 Hz，消灭 log10(0)。
    func x(forBin bin: Int, sampleRate: Double, fftSize: Int) -> CGFloat {
        guard fftSize > 0, bin >= 0 else { return plotRect.minX }
        let rawFrequency = Double(bin) * sampleRate / Double(fftSize)
        let safeFrequency = max(rawFrequency, minFrequency)
        return x(forFrequency: safeFrequency)
    }

    /// 线性分贝 → Y 像素。
    /// yRatio = 1 − (dB − (−20)) / (120 − (−20))；dB = −20 → 底部，dB = 120 → 顶部
    func y(forDecibels db: Float) -> CGFloat {
        guard plotRect.height > 0 else { return plotRect.midY }
        let plotDB = SpectrumDSPGuards.clampedPlotDecibels(db)
        let yRatio = 1.0 - (Double(plotDB) - minDecibels) / decibelSpan
        guard yRatio.isFinite else { return plotRect.maxY }
        return plotRect.minY + CGFloat(yRatio) * plotRect.height
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

    private static let plotInsets = EdgeInsets(top: 14, leading: 34, bottom: 8, trailing: 10)

    private static let frequencyGridHz: [Double] = [62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    private static let decibelGridValues: [Int] = [-20, 0, 20, 40, 60, 80, 100, 120]

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
                Text(placeholderText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .drawingGroup()
    }

    private var placeholderText: String {
        isActive ? L10n.spectrumLoading : L10n.spectrumIdle
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
            style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawPeakHoldSpectrum(
        context: inout GraphicsContext,
        coords: SpectrumPlotCoordinateSystem,
        spectrum: FFTSpectrum
    ) {
        guard !spectrum.peakDecibels.isEmpty,
              spectrum.peakDecibels.count == spectrum.decibels.count else { return }

        let path = spectrumPath(
            decibels: spectrum.peakDecibels,
            coords: coords,
            sampleRate: spectrum.sampleRate,
            fftSize: spectrum.fftSize
        )
        context.stroke(
            path,
            with: .color(.pink),
            style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
        )
    }

    /// 绘制实时/峰值保持曲线：Bin 1…511（~43 Hz 起），与峰值文字检索解耦。
    private func spectrumPath(
        decibels: [Float],
        coords: SpectrumPlotCoordinateSystem,
        sampleRate: Double,
        fftSize: Int
    ) -> Path {
        var path = Path()
        let startBin = SpectrumDSPGuards.pathDrawingMinBin
        let endBin = min(512, decibels.count, fftSize / 2)
        guard endBin > startBin else { return path }

        for bin in startBin..<endBin {
            let rawFrequency = Float(bin) * Float(sampleRate) / Float(fftSize)
            let x = coords.x(forFrequency: Double(rawFrequency))
            let y = coords.y(forDecibels: decibels[bin])

            guard x.isFinite, y.isFinite else { continue }
            let point = CGPoint(x: x, y: y)

            if bin == startBin {
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
        let peakDecibels = spectrum.peakDecibels
        guard !peakDecibels.isEmpty,
              peakDecibels.count == spectrum.decibels.count else { return }

        // 仅峰值悬浮文字从 Bin 3 起检索，与曲线绘制（Bin 1 起）分离
        let labelMinBin = SpectrumDSPGuards.peakLabelMinBin
        guard let peakBin = peakDecibels.enumerated()
            .filter({ $0.offset >= labelMinBin })
            .max(by: { $0.element < $1.element })?.offset,
              peakDecibels[peakBin] > Float(coords.minDecibels) + 4 else { return }

        let peakDB = peakDecibels[peakBin]
        let peakFrequency = max(
            Double(peakBin) * spectrum.sampleRate / Double(spectrum.fftSize),
            SpectrumDSPGuards.minimumPlotFrequency
        )
        let anchor = CGPoint(
            x: coords.x(forFrequency: peakFrequency),
            y: coords.y(forDecibels: peakDB)
        )
        guard anchor.x.isFinite, anchor.y.isFinite else { return }

        // 3 px 实心顶点
        let dotRect = CGRect(x: anchor.x - 1.5, y: anchor.y - 1.5, width: 3, height: 3)
        context.fill(Path(ellipseIn: dotRect), with: .color(.pink))

        let label = Self.formatPeakFrequency(peakFrequency)
        guard !label.isEmpty else { return }

        let resolved = context.resolve(
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.95))
        )
        context.draw(resolved, at: CGPoint(x: anchor.x, y: anchor.y - 5), anchor: .bottom)
    }

    // MARK: - 标签格式化

    private static func formatGridFrequency(_ hz: Double) -> String {
        switch hz {
        case 1_000...: return String(format: "%.0fK", hz / 1000)
        default: return String(format: "%.0f Hz", hz)
        }
    }

    private static func formatPeakFrequency(_ hz: Double) -> String {
        guard hz.isFinite, hz >= SpectrumDSPGuards.minimumPlotFrequency else { return "" }
        if hz >= 10_000 { return String(format: "%.0f Hz", hz) }
        if hz >= 1_000 { return String(format: "%.1f kHz", hz / 1000) }
        return String(format: "%.0f Hz", hz)
    }
}
