import Foundation

nonisolated enum WidgetStrings {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: WidgetLocalizationBundle.bundle, comment: "")
    }

    static var liveTitle: String { text("widget.live.title") }
    static var statsTitle: String { text("widget.stats.title") }
    static var statusMonitoring: String { text("widget.status.monitoring") }
    static var statusIdle: String { text("widget.status.idle") }
    static var placeholderStart: String { text("widget.placeholder.start") }
    static var intentStart: String { text("widget.intent.start") }
    static var intentStop: String { text("widget.intent.stop") }
    static var statMax: String { text("widget.stat.max") }
    static var statMin: String { text("widget.stat.min") }
    static var statAvg: String { text("widget.stat.avg") }
    static var statLeq: String { text("widget.stat.leq") }

    static func lastUpdated(_ relative: String) -> String {
        String(format: text("widget.lastUpdated"), relative)
    }
}

enum WidgetRelativeTimeFormatter {
    static func string(from date: Date, relativeTo now: Date = .now) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 {
            return WidgetStrings.text("widget.time.justNow")
        }
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: WidgetStrings.text("widget.time.minutesAgo"), minutes)
        }
        if interval < 86_400 {
            let hours = Int(interval / 3600)
            return String(format: WidgetStrings.text("widget.time.hoursAgo"), hours)
        }
        let days = Int(interval / 86_400)
        return String(format: WidgetStrings.text("widget.time.daysAgo"), days)
    }
}
