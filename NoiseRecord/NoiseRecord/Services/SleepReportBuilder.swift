import Foundation

enum SleepReportBuilder {
    static func buildSummary(
        overallLeq: Float,
        noiseFloor: Float,
        anomalies: [SleepAnomalyCandidate],
        temperatureCelsius: Double? = nil,
        humidityPercent: Int? = nil,
        calendar: Calendar = .current
    ) -> String {
        let overall = String(format: "%.0f", overallLeq)
        let base: String

        if let primary = anomalies.max(by: { $0.peakDB < $1.peakDB }) {
            let time = formattedTime(primary.timestamp, calendar: calendar)
            let peak = String(format: "%.0f", primary.peakDB)
            let impact = impactText(for: primary.timestamp, calendar: calendar)
            base = L10n.sleepReportSummaryWithAnomaly(overall, time, peak, impact)
        } else {
            base = L10n.sleepReportSummaryQuiet(overall)
        }

        guard let environment = SleepEnvironmentFormatter.appSummaryClause(
            temperatureCelsius: temperatureCelsius,
            humidityPercent: humidityPercent
        ) else {
            return base
        }

        return L10n.sleepReportSummaryEnvironment(base, environment)
    }

    static func impactText(for timestamp: Date, calendar: Calendar = .current) -> String {
        switch SleepNoiseAnalyzer.sleepImpactHint(for: timestamp, calendar: calendar) {
        case .deepSleep:
            L10n.sleepReportImpactDeepSleep
        case .lightSleep:
            L10n.sleepReportImpactLightSleep
        }
    }

    private static func formattedTime(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = AppLocalization.resolvedLocale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
