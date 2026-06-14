import StoreKit
import SwiftUI
import UIKit

nonisolated enum AppReviewPresenter {
    static let appStoreID = "6779128095"

    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    @MainActor
    static func requestReview(using requestReview: RequestReviewAction) {
        requestReview()
    }

    @MainActor
    static func openAppStoreReviewPage() {
        UIApplication.shared.open(writeReviewURL)
    }
}
