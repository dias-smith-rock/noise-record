import Foundation

nonisolated enum SupportContact {
    static let email = "music.player.250617@gmail.com"

    static var mailtoURL: URL {
        URL(string: "mailto:\(email)")!
    }
}
