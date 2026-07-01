import Foundation

enum EvidenceTimeFormatting {
    static func playbackTime(_ time: TimeInterval) -> String {
        let total = max(0, time)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let centiseconds = Int((total.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    static func remainingTime(_ remaining: TimeInterval) -> String {
        "-\(playbackTime(remaining))"
    }

    static func compactDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        let seconds = total % 60
        if minutes < 60 { return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
