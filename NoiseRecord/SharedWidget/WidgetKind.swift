import Foundation

nonisolated enum WidgetKind {
    static let liveMeter = "LiveMeterWidget"
    static let sessionStats = "SessionStatsWidget"
    static let monitoringControl = "MonitoringControlWidget"

    static let all: [String] = [liveMeter, sessionStats, monitoringControl]
}
