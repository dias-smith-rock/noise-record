import Foundation

nonisolated enum LegalURLs {
    private static let websiteBase = "https://www.decibelmeterpro.com"

    static var privacyPolicy: URL {
        URL(string: "\(websiteBase)/privacy.html")!
    }

    static var termsOfService: URL {
        URL(string: "\(websiteBase)/terms.html")!
    }
}
