import SwiftUI

private struct AppLanguageRevisionKey: EnvironmentKey {
    static let defaultValue = UUID()
}

extension EnvironmentValues {
    var appLanguageRevision: UUID {
        get { self[AppLanguageRevisionKey.self] }
        set { self[AppLanguageRevisionKey.self] = newValue }
    }
}

/// Re-renders localized strings when the app language changes without resetting navigation or lifecycle tasks.
struct AppLanguageRefreshModifier: ViewModifier {
    @Environment(\.appLanguageRevision) private var revision

    func body(content: Content) -> some View {
        let _ = revision
        return content
    }
}

extension View {
    func observesAppLanguage() -> some View {
        modifier(AppLanguageRefreshModifier())
    }
}
