import Foundation

struct SleepLocationSnapshot: Sendable, Equatable {
    let latitude: Double?
    let longitude: Double?

    init(latitude: Double? = nil, longitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

enum SleepLocationFormatter {
    static func pdfEnglishSummary(
        start: SleepLocationSnapshot?,
        end: SleepLocationSnapshot? = nil,
        startPlaceName: String? = nil,
        endPlaceName: String? = nil
    ) -> String? {
        formattedRange(
            start: start,
            end: end,
            startPlaceName: startPlaceName,
            endPlaceName: endPlaceName
        )
    }

    @MainActor
    static func resolvePDFEnglishSummary(
        start: SleepLocationSnapshot?,
        end: SleepLocationSnapshot? = nil
    ) async -> String? {
        async let startPlaceName = resolvePlaceName(for: start)
        async let endPlaceName = resolvePlaceName(for: end)
        return pdfEnglishSummary(
            start: start,
            end: end,
            startPlaceName: await startPlaceName,
            endPlaceName: await endPlaceName
        )
    }

    static func pdfNEMRLine(
        start: SleepLocationSnapshot?,
        end: SleepLocationSnapshot? = nil,
        startPlaceName: String? = nil,
        endPlaceName: String? = nil
    ) -> String {
        guard let english = pdfEnglishSummary(
            start: start,
            end: end,
            startPlaceName: startPlaceName,
            endPlaceName: endPlaceName
        ) else {
            return "Not recorded / 未记录"
        }
        return "\(english) / \(english)"
    }

    static func pdfNEMRLine(fromResolvedSummary summary: String?) -> String {
        guard let summary, !summary.isEmpty else {
            return "Not recorded / 未记录"
        }
        return "\(summary) / \(summary)"
    }

    static func formattedCoordinates(latitude: Double, longitude: Double) -> String {
        let latHemisphere = latitude >= 0 ? "N" : "S"
        let lonHemisphere = longitude >= 0 ? "E" : "W"
        return String(
            format: "%.4f° %@, %.4f° %@",
            abs(latitude),
            latHemisphere,
            abs(longitude),
            lonHemisphere
        )
    }

    @MainActor
    private static func resolvePlaceName(for snapshot: SleepLocationSnapshot?) async -> String? {
        guard let snapshot,
              let latitude = snapshot.latitude,
              let longitude = snapshot.longitude else {
            return nil
        }
        return await EvidenceGeocoder.abbreviatedPlaceName(
            latitude: latitude,
            longitude: longitude
        )
    }

    private static func formattedRange(
        start: SleepLocationSnapshot?,
        end: SleepLocationSnapshot?,
        startPlaceName: String?,
        endPlaceName: String?
    ) -> String? {
        let startText = start.flatMap {
            formattedSingle(snapshot: $0, placeName: startPlaceName)
        }
        let endText = end.flatMap {
            formattedSingle(snapshot: $0, placeName: endPlaceName)
        }

        switch (startText, endText) {
        case let (start?, end?) where start != end:
            return "\(start) → \(end) (session start → end)"
        case let (start?, _):
            return "\(start) (session start)"
        case (_, let end?):
            return "\(end) (session end)"
        default:
            return nil
        }
    }

    private static func formattedSingle(
        snapshot: SleepLocationSnapshot,
        placeName: String?
    ) -> String? {
        guard let latitude = snapshot.latitude,
              let longitude = snapshot.longitude else {
            return nil
        }
        let coordinates = formattedCoordinates(latitude: latitude, longitude: longitude)
        if let placeName, !placeName.isEmpty {
            return "\(coordinates) — \(placeName)"
        }
        return coordinates
    }
}
