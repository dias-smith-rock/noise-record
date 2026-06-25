import Foundation

/// 频谱 DSP / 绘图共享边界常量，防止 log10(0) 与 0 dB 硬截断。
nonisolated enum SpectrumDSPGuards {
    /// 悬浮峰值文字检索起始 Bin（跳过 0 Hz 直流与 ~129 Hz 以下噪底误标）。
    static let peakLabelMinBin = 3

    /// 向后兼容：峰值文字检索别名。
    static let peakTrackingMinBin = peakLabelMinBin

    /// 绘图路径起始 Bin：仅跳过 Bin 0（直流）。
    /// 标准 1024：Bin 1 ≈ 43 Hz；高级 2048：Bin 1 ≈ 21.5 Hz。
    static let pathDrawingMinBin = 1

    /// FFT 输出中仅压制的直流 Bin 数量（Bin 0）；不触碰 Bin 1/2 低频共振数据。
    static let dcSuppressBinCount = 1

    /// 对数频率轴下界（Hz）。
    static let minimumPlotFrequency: Double = 20

    /// DSP 输出下限：仅防止 log10 产生 −∞，绝不钳位到 0。
    static let analyzerDecibelFloor: Float = -120

    /// 图表可见域（Y 轴映射边界，与 SpectrumPlotCoordinateSystem 一致）。
    static let plotDecibelMin: Float = -20
    static let plotDecibelMax: Float = 120

    /// DSP 链路：允许负 dBA，仅做声学底噪钳位。
    static func clampedAnalyzerDecibels(_ db: Float) -> Float {
        guard db.isFinite else { return analyzerDecibelFloor }
        return max(db, analyzerDecibelFloor)
    }

    /// 绘图映射：裁剪至可见域，负值原样保留（如 −15 dBA 落在 0 与 −20 网格之间）。
    static func clampedPlotDecibels(_ db: Float) -> Float {
        guard db.isFinite else { return plotDecibelMin }
        return min(max(db, plotDecibelMin), plotDecibelMax)
    }
}
