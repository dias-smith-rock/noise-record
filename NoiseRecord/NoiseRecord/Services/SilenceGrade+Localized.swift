import Foundation

extension SilenceGrade {
    var localizedTitle: String {
        switch self {
        case .a: String(localized: "silenceGrade.a.title")
        case .b: String(localized: "silenceGrade.b.title")
        case .c: String(localized: "silenceGrade.c.title")
        case .d: String(localized: "silenceGrade.d.title")
        }
    }

    var localizedDescription: String {
        switch self {
        case .a: String(localized: "silenceGrade.a.description")
        case .b: String(localized: "silenceGrade.b.description")
        case .c: String(localized: "silenceGrade.c.description")
        case .d: String(localized: "silenceGrade.d.description")
        }
    }
}
