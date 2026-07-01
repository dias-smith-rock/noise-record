import Foundation

/// 全屏 LED Eco 模式的 UI 刷新策略（仅影响展示，不影响 `NoiseMonitorEngine` 采集）。
enum FullscreenLEDEcoModePolicy {
    static let significantDecibelChangeThreshold: Float = 3

    /// Eco 主读数刷新间隔（与右上角提示一致，每分钟更新一次）。
    static let decibelRefreshInterval: TimeInterval = 60

    /// 时钟仅显示到分钟，Eco 下由 `TimelineView` 按分钟边界刷新。
    static let clockRefreshInterval: TimeInterval = 60

    /// 波形静态快照间隔（低于实时刷新，高于完全冻结）。
    static let waveformSnapshotInterval: TimeInterval = 12

    static func shouldRefreshThrottledDecibel(current: Float, displayed: Float) -> Bool {
        abs(current - displayed) >= significantDecibelChangeThreshold
    }

    /// 当前分钟的起始时刻，用作 Eco 时钟 `TimelineView` 锚点。
    static func startOfCurrentMinute(for date: Date = Date(), calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Eco 时钟是否需要同步（小时或分钟与展示值不同）。
    static func shouldRefreshClock(current: Date, displayed: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: current) != calendar.component(.hour, from: displayed)
            || calendar.component(.minute, from: current) != calendar.component(.minute, from: displayed)
    }

    /// 距下一分钟边界的秒数。
    static func secondsUntilNextMinuteBoundary(from date: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        let second = calendar.component(.second, from: date)
        let nanosecond = calendar.component(.nanosecond, from: date)
        let elapsedInMinute = Double(second) + Double(nanosecond) / 1_000_000_000
        return max(0.05, 60 - elapsedInMinute)
    }
}
