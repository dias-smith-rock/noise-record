import Foundation

enum SleepPDFPreviewAccessStore {
    private static let consumedKey = "sleep.pdfPreview.globalFreeConsumed"

    static var hasConsumedGlobalFreePreview: Bool {
        UserDefaults.standard.bool(forKey: consumedKey)
    }

    static func markGlobalFreePreviewConsumed() {
        UserDefaults.standard.set(true, forKey: consumedKey)
    }

    static func shouldBlurPreview(isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        return hasConsumedGlobalFreePreview
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: consumedKey)
    }
    #endif
}
