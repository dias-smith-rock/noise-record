import AVFoundation
import CryptoKit
import UIKit

/// Generates a poster frame for evidence videos and caches JPEG files under Caches.
enum VideoPosterThumbnailCache {
    private final class ImageBox: NSObject {
        let image: UIImage
        init(_ image: UIImage) { self.image = image }
    }

    private static let memory = NSCache<NSString, ImageBox>()
    private static let folderName = "VideoPosterThumbnails"
    private static let maxPixelSize = CGSize(width: 360, height: 240)
    private static let posterTime = CMTime(seconds: 0.12, preferredTimescale: 600)

    static func image(for videoURL: URL) async -> UIImage? {
        let key = cacheKey(for: videoURL)
        if let cached = memory.object(forKey: key as NSString)?.image {
            return cached
        }
        if let disk = loadFromDisk(key: key) {
            memory.setObject(ImageBox(disk), forKey: key as NSString)
            return disk
        }
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }
        guard let generated = await generatePoster(for: videoURL) else { return nil }
        memory.setObject(ImageBox(generated), forKey: key as NSString)
        saveToDisk(generated, key: key)
        return generated
    }

    static func invalidate(for videoURL: URL) {
        let prefix = pathHash(for: videoURL)
        memory.removeObject(forKey: cacheKey(for: videoURL) as NSString)
        let directory = cacheDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func cacheKey(for videoURL: URL) -> String {
        let values = try? videoURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let mtime = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        let size = values?.fileSize ?? 0
        return "\(pathHash(for: videoURL))_\(mtime)_\(size)"
    }

    static func diskURL(for videoURL: URL) -> URL {
        cacheDirectory().appendingPathComponent("\(cacheKey(for: videoURL)).jpg")
    }

    private static func generatePoster(for videoURL: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let asset = AVURLAsset(url: videoURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = maxPixelSize
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)
                do {
                    let cgImage = try generator.copyCGImage(at: posterTime, actualTime: nil)
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func cacheDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = caches.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func pathHash(for videoURL: URL) -> String {
        let path = videoURL.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func loadFromDisk(key: String) -> UIImage? {
        let url = cacheDirectory().appendingPathComponent("\(key).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private static func saveToDisk(_ image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.72) else { return }
        try? data.write(to: cacheDirectory().appendingPathComponent("\(key).jpg"), options: .atomic)
    }
}
