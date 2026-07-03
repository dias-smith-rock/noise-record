import Foundation

enum LocationWeatherPermissionPromptStore {
    private static let dismissedKey = "location.weather.permissionPrompt.userDismissed"

    static var userDismissedPrompt: Bool {
        UserDefaults.standard.bool(forKey: dismissedKey)
    }

    static func markPromptDismissed() {
        UserDefaults.standard.set(true, forKey: dismissedKey)
    }
}
