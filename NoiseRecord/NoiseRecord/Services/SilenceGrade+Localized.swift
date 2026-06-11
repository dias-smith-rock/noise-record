import Foundation

extension SilenceGrade {
    var localizedTitle: String {
        switch self {
        case .a: AppLocalization.string( "silenceGrade.a.title")
        case .b: AppLocalization.string( "silenceGrade.b.title")
        case .c: AppLocalization.string( "silenceGrade.c.title")
        case .d: AppLocalization.string( "silenceGrade.d.title")
        }
    }

    var localizedDescription: String {
        switch self {
        case .a: AppLocalization.string( "silenceGrade.a.description")
        case .b: AppLocalization.string( "silenceGrade.b.description")
        case .c: AppLocalization.string( "silenceGrade.c.description")
        case .d: AppLocalization.string( "silenceGrade.d.description")
        }
    }
}
