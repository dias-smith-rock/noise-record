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
        end: SleepLocationSnapshot? = nil
    ) -> String? {
        formattedRange(start: start, end: end)
    }

    static func pdfNEMRLine(
        start: SleepLocationSnapshot?,
        end: SleepLocationSnapshot? = nil
    ) -> String {
        guard let english = formattedRange(start: start, end: end) else {
            return "Not recorded / 未记录"
        }
        return "\(english) / \(english)"
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

    private static func formattedRange(
        start: SleepLocationSnapshot?,
        end: SleepLocationSnapshot?
    ) -> String? {
        let startText = start.flatMap(formattedSingle(snapshot:))
        let endText = end.flatMap(formattedSingle(snapshot:))

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

    private static func formattedSingle(snapshot: SleepLocationSnapshot) -> String? {
        guard let latitude = snapshot.latitude,
              let longitude = snapshot.longitude else {
            return nil
        }
        return formattedCoordinates(latitude: latitude, longitude: longitude)
    }
}
