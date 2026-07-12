import Foundation

struct SleepEnvironmentSnapshot: Sendable, Equatable {
    let temperatureCelsius: Double?
    let humidityPercent: Int?
}

enum SleepEnvironmentFormatter {
    static func pdfEnglishSummary(
        start: SleepEnvironmentSnapshot?,
        end: SleepEnvironmentSnapshot? = nil
    ) -> String? {
        guard let text = formattedRange(start: start, end: end, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return text
    }

    static func pdfNEMRLine(
        start: SleepEnvironmentSnapshot?,
        end: SleepEnvironmentSnapshot? = nil
    ) -> String {
        let english = formattedRange(
            start: start,
            end: end,
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? "Not recorded"
        let chinese = formattedRange(
            start: start,
            end: end,
            locale: Locale(identifier: "zh-Hans")
        ) ?? "未记录"
        return "\(english) / \(chinese)"
    }

    static func appSummaryClause(
        temperatureCelsius: Double?,
        humidityPercent: Int?
    ) -> String? {
        guard temperatureCelsius != nil || humidityPercent != nil else { return nil }
        let snapshot = SleepEnvironmentSnapshot(
            temperatureCelsius: temperatureCelsius,
            humidityPercent: humidityPercent
        )
        return formattedSingle(snapshot: snapshot, locale: AppLocalization.resolvedLocale)
    }

    private static func formattedRange(
        start: SleepEnvironmentSnapshot?,
        end: SleepEnvironmentSnapshot?,
        locale: Locale
    ) -> String? {
        let startText = start.flatMap { formattedSingle(snapshot: $0, locale: locale) }
        let endText = end.flatMap { formattedSingle(snapshot: $0, locale: locale) }

        switch (startText, endText) {
        case let (start?, end?) where start != end:
            return "\(start) → \(end)"
        case let (start?, _):
            return start
        case (_, let end?):
            return end
        default:
            return nil
        }
    }

    private static func formattedSingle(snapshot: SleepEnvironmentSnapshot, locale: Locale) -> String? {
        var parts: [String] = []
        if let temperatureCelsius = snapshot.temperatureCelsius {
            parts.append(formatTemperature(temperatureCelsius, locale: locale))
        }
        if let humidityPercent = snapshot.humidityPercent {
            parts.append("\(humidityPercent)% RH")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    private static func formatTemperature(_ celsius: Double, locale: Locale) -> String {
        if AppAppearanceSettings.shared.temperatureUnitPreference.usesFahrenheit {
            let fahrenheit = celsius * 9 / 5 + 32
            return String(format: "%.0f°F", fahrenheit)
        }
        return String(format: "%.0f°C", celsius)
    }
}
