import Foundation

enum SleepForensicReportFormat: String, CaseIterable, Identifiable {
    case legacyOvernight
    case nighttimeEnvironmental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .legacyOvernight:
            "Overnight Acoustic Monitoring Report"
        case .nighttimeEnvironmental:
            "Nighttime Environmental Noise Monitoring Report (NEMR)"
        }
    }
}
