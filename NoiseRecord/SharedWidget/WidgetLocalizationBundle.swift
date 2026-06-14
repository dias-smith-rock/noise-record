import Foundation

enum WidgetLocalizationBundle {
    private final class Token {}

    static var bundle: Bundle {
        Bundle(for: Token.self)
    }
}
