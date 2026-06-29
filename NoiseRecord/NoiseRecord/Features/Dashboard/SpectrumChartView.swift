import SwiftUI

// MARK: - 坐标系

/// 频谱图统一坐标映射：X 为对数频率，Y 为线性分贝。
/// 网格线与数据曲线共用同一套公式，保证物理对齐。
struct SpectrumPlotCoordinateSystem: Sendable {
    let plotRect: CGRect

    /// 横轴下界：20 Hz（人耳可闻低频端）
    let minFrequency: Double = 20
    /// 横轴上界：22050 Hz（44100 Hz 采样率的 Nyquist 频率）
    let maxFrequency: Double = 22_050
    /// 纵轴下界：-20 dBA
    var minDecibels: Double { Double(SpectrumDSPGuards.plotDecibelMin) }
    /// 纵轴上界：120 dBA
    var maxDecibels: Double { Double(SpectrumDSPGuards.plotDecibelMax) }

    private let logMin: Double
    private let logMax: Double
    private let logSpan: Double
    private var decibelSpan: Double { max(maxDecibels - minDecibels, 1e-9) }

    init(plotRect: CGRect) {
        self.plotRect = plotRect
        self.logMin = Self.safeLog10(minFrequency)
        self.logMax = Self.safeLog10(maxFrequency)
        self.logSpan = max(logMax - logMin, 1e-9)
    }

    /// 对数频率 → X 像素。
    /// xRatio = (log₁₀(f) − log₁₀(20)) / (log₁₀(22050) − log₁₀(20))
    func x(forFrequency hz: Double) -> CGFloat {
        guard plotRect.width > 0 else { return plotRect.minX }
        let clamped = min(max(hz, minFrequency), maxFrequency)
        let normalized = (Self.safeLog10(clamped) - logMin) / logSpan
        guard normalized.isFinite else { return plotRect.minX }
        return plotRect.minX + CGFloat(normalized) * plotRect.width
    }

    /// 第 i 个 FFT Bin → 物理频率 → X 像素（Double 精度，避免低频阶梯锯齿）。
    func x(forBin bin: Int, sampleRate: Double, fftSize: Int) -> CGFloat {
        guard fftSize > 0, bin >= 0 else { return plotRect.minX }
        let binWidth = sampleRate / Double(fftSize)
        let frequency = max(Double(bin) * binWidth, minFrequency)
        return x(forFrequency: frequency)
    }

    /// 线性分贝 → Y 像素。
    func y(forDecibels db: Float) -> CGFloat {
        guard plotRect.height > 0 else { return plotRect.midY }
        let plotDB = SpectrumDSPGuards.clampedPlotDecibels(db)
        let yRatio = 1.0 - (Double(plotDB) - minDecibels) / decibelSpan
        guard yRatio.isFinite else { return plotRect.maxY }
        return plotRect.minY + CGFloat(yRatio) * plotRect.height
    }

    private static func safeLog10(_ value: Double) -> Double {
        let floor = SpectrumDSPGuards.minimumPlotFrequency
        guard value > 0 else { return log10(floor) }
        let result = log10(value)
        return result.isFinite ? result : log10(floor)
    }
}

// MARK: - 路径构建

/// 以 Double 频率步长构建频谱折线，支持 512 / 1024 动态 Bin 数。
struct SpectrumPathBuilder {
    let coords: SpectrumPlotCoordinateSystem
    let sampleRate: Double
    let fftSize: Int
    let binWidth: Double

    init(coords: SpectrumPlotCoordinateSystem, sampleRate: Double, fftSize: Int) {
        self.coords = coords
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.binWidth = sampleRate / Double(fftSize)
    }

    func buildPath(decibels: [Float]) -> Path {
        var path = Path()
        let startBin = SpectrumDSPGuards.pathDrawingMinBin
        let endBin = min(decibels.count, fftSize / 2)
        guard endBin > startBin else { return path }

        for bin in startBin..<endBin {
            let frequency = max(Double(bin) * binWidth, coords.minFrequency)
            let x = coords.x(forFrequency: frequency)
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
            let plotRect = plotRect(in: geometry.size)
            let coords = SpectrumPlotCoordinateSystem(plotRect: plotRect)

            Canvas { context, size in
                drawFrequencyGrid(context: &context, coords: coords)
                drawDecibelGrid(context: &context, coords: coords)

                if let spectrum, !spectrum.decibels.isEmpty {
                    drawLiveSpectrum(context: &context, coords: coords, spectrum: spectrum)
                    drawPeakHoldSpectrum(context: &context, coords: coords, spectrum: spectrum)
                    if let livePeak = livePeakMark(for: spectrum, coords: coords) {
                        drawPeakDot(context: &context, at: livePeak.anchor, color: .green)
                    }
                    if let holdPeak = peakHoldMark(for: spectrum, coords: coords) {
                        drawPeakDot(context: &context, at: holdPeak.anchor, color: .pink)
                    }
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
        .overlay {
            GeometryReader { geometry in
                let coords = SpectrumPlotCoordinateSystem(plotRect: plotRect(in: geometry.size))
                if let spectrum {
                    let livePeak = livePeakMark(for: spectrum, coords: coords)
                    let holdPeak = peakHoldMark(for: spectrum, coords: coords)
                    let labelsOverlap: Bool = {
                        guard let livePeak, let holdPeak else { return false }
                        return abs(livePeak.anchor.x - holdPeak.anchor.x) < 28
                    }()

                    if let livePeak {
                        peakLabelView(livePeak, accent: .green)
                            .position(
                                x: livePeak.anchor.x,
                                y: livePeak.anchor.y - (labelsOverlap ? 22 : 12)
                            )
                    }
                    if let holdPeak {
                        peakLabelView(holdPeak, accent: .pink)
                            .position(x: holdPeak.anchor.x, y: holdPeak.anchor.y - 12)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var placeholderText: String {
        isActive ? L10n.spectrumLoading : L10n.spectrumIdle
    }

    // MARK: - 布局

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

    /// 绘制实时/峰值保持曲线：Bin 1…N−1，N = fftSize / 2（512 或 1024）。
    private func spectrumPath(
        decibels: [Float],
        coords: SpectrumPlotCoordinateSystem,
        sampleRate: Double,
        fftSize: Int
    ) -> Path {
        SpectrumPathBuilder(
            coords: coords,
            sampleRate: sampleRate,
            fftSize: fftSize
        ).buildPath(decibels: decibels)
    }

    // MARK: - 峰值标注

    private struct SpectrumPeakMark: Equatable {
        let anchor: CGPoint
        let label: String
    }

    private func livePeakMark(
        for spectrum: FFTSpectrum,
        coords: SpectrumPlotCoordinateSystem
    ) -> SpectrumPeakMark? {
        peakMark(
            decibels: spectrum.decibels,
            sampleRate: spectrum.sampleRate,
            fftSize: spectrum.fftSize,
            coords: coords
        )
    }

    private func peakHoldMark(
        for spectrum: FFTSpectrum,
        coords: SpectrumPlotCoordinateSystem
    ) -> SpectrumPeakMark? {
        guard !spectrum.peakDecibels.isEmpty,
              spectrum.peakDecibels.count == spectrum.decibels.count else { return nil }
        return peakMark(
            decibels: spectrum.peakDecibels,
            sampleRate: spectrum.sampleRate,
            fftSize: spectrum.fftSize,
            coords: coords
        )
    }

    private func peakMark(
        decibels: [Float],
        sampleRate: Double,
        fftSize: Int,
        coords: SpectrumPlotCoordinateSystem
    ) -> SpectrumPeakMark? {
        guard !decibels.isEmpty else { return nil }

        let labelMinBin = SpectrumDSPGuards.peakLabelMinBin
        guard let peakBin = decibels.enumerated()
            .filter({ $0.offset >= labelMinBin })
            .max(by: { $0.element < $1.element })?.offset,
              decibels[peakBin] > SpectrumDSPGuards.plotDecibelMin + 4 else { return nil }

        let peakDB = decibels[peakBin]
        let binWidth = sampleRate / Double(fftSize)
        let peakFrequency = max(Double(peakBin) * binWidth, coords.minFrequency)
        let label = Self.formatPeakFrequency(peakFrequency)
        guard !label.isEmpty else { return nil }

        let anchor = CGPoint(
            x: coords.x(forFrequency: peakFrequency),
            y: coords.y(forDecibels: peakDB)
        )
        guard anchor.x.isFinite, anchor.y.isFinite else { return nil }

        return SpectrumPeakMark(anchor: anchor, label: label)
    }

    private func drawPeakDot(context: inout GraphicsContext, at anchor: CGPoint, color: Color) {
        let dotRect = CGRect(x: anchor.x - 1.5, y: anchor.y - 1.5, width: 3, height: 3)
        context.fill(Path(ellipseIn: dotRect), with: .color(color))
    }

    private func peakLabelView(_ mark: SpectrumPeakMark, accent: Color) -> some View {
        Text(mark.label)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(Color(.systemBackground).opacity(0.96))
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            }
            .overlay {
                Capsule()
                    .strokeBorder(accent.opacity(0.35), lineWidth: 0.5)
            }
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
