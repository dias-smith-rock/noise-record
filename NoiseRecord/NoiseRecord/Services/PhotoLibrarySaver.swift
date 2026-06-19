import Photos

enum PhotoLibrarySaver {
    enum MediaKind {
        case video
        case image
    }

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif"
    ]

    static func requestAddOnlyAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return status == .authorized || status == .limited
        @unknown default:
            return false
        }
    }

    static func mediaKind(for url: URL) -> MediaKind {
        imageExtensions.contains(url.pathExtension.lowercased()) ? .image : .video
    }

    static func saveFile(at url: URL) async throws -> MediaKind {
        let kind = mediaKind(for: url)
        try await PHPhotoLibrary.shared().performChanges {
            switch kind {
            case .image:
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            case .video:
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        }
        return kind
    }

    static func saveFiles(at urls: [URL]) async throws {
        guard !urls.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            for url in urls {
                switch mediaKind(for: url) {
                case .image:
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                case .video:
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
            }
        }
    }

    static func successMessage(for kind: MediaKind) -> String {
        switch kind {
        case .video: L10n.playerSavedVideoToPhotos
        case .image: L10n.playerSavedPhotoToPhotos
        }
    }
}
