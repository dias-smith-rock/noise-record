import Foundation

enum DurationFormatting {
    /// Formats duration adaptively: `HH:MM:SS`, `MM:SS`, or `00:SS`.
    static func hms(from total: TimeInterval) -> String {
        let totalSeconds = max(0, Int(total.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "00:%02d", seconds)
    }

    static func fileSize(from bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Compact duration for sleep history rows, e.g. `7h 12m`.
    static func compactHoursMinutes(from total: TimeInterval) -> String {
        let totalSeconds = max(0, Int(total.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0, minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}
