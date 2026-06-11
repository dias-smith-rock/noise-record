import Foundation

nonisolated enum LegalURLs {
    private static let websiteBase = "https://www.noise.nx.kg"

    static var privacyPolicy: URL {
        URL(string: "\(websiteBase)/privacy.html")!
    }

    static var termsOfService: URL {
        URL(string: "\(websiteBase)/terms.html")!
    }
}
