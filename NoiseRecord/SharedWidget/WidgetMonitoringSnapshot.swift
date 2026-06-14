import Foundation

nonisolated enum WidgetAppGroup {
    static let identifier = "group.com.goodcraft.NoiseRecord"
}

nonisolated enum WidgetDeepLink {
    static let scheme = "decibelpro"
    static let monitorHost = "monitor"

    static var monitorURL: URL {
        URL(string: "\(scheme)://\(monitorHost)")!
    }

    static var monitorStartURL: URL {
        URL(string: "\(scheme)://\(monitorHost)?action=start")!
    }

    static func parsesActionStart(from url: URL) -> Bool {
        guard url.scheme == scheme, url.host == monitorHost else { return false }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return components.queryItems?.contains(where: { $0.name == "action" && $0.value == "start" }) == true
    }
}

nonisolated enum WidgetDarwinNotifications {
    static let pendingActionName = "com.goodcraft.NoiseRecord.widget.pendingAction"
}

enum WidgetPendingAction: String, Codable, Sendable {
    case start
    case stop
}

enum WidgetRecordingState: String, Codable, Sendable {
    case idle
    case recording
    case coolingDown
}

struct WidgetMonitoringSnapshot: Codable, Sendable, Equatable {
    var currentDB: Float
    var maxDB: Float
    var minDB: Float
    var averageDB: Float
    var leq: Float
    var weightingBadge: String
    var isHighSensitivity: Bool
    var isMonitoring: Bool
    var recordingState: WidgetRecordingState
    var history: [Float]
    var updatedAt: Date

    static let historyLimit = 60

    var hasData: Bool {
        updatedAt.timeIntervalSince1970 > 0
    }

    func isEffectivelyMonitoring(at date: Date = .now) -> Bool {
        if isMonitoring { return true }
        return date.timeIntervalSince(updatedAt) < 8 && currentDB > 0
    }

    func isRecentlyActive(at date: Date = .now) -> Bool {
        date.timeIntervalSince(updatedAt) < 30
    }

    static var placeholder: WidgetMonitoringSnapshot {
        WidgetMonitoringSnapshot(
            currentDB: 0,
            maxDB: 0,
            minDB: 0,
            averageDB: 0,
            leq: 0,
            weightingBadge: "A",
            isHighSensitivity: false,
            isMonitoring: false,
            recordingState: .idle,
            history: [],
            updatedAt: .distantPast
        )
    }
}
