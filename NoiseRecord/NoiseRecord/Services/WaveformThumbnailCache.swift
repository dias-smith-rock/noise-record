import Foundation

/// In-memory cache for list waveform thumbnails. Disk is read at most once per file path.
enum WaveformThumbnailCache {
    private final class CacheBox: NSObject {
        let samples: [Float]
        init(_ samples: [Float]) { self.samples = samples }
    }

    private static let cache = NSCache<NSString, CacheBox>()
    private static let maxThumbnailPoints = 120

    static func decibels(for fileURL: URL) -> [Float]? {
        let key = cacheKey(for: fileURL)
        if let cached = cache.object(forKey: key)?.samples {
            return cached
        }

        guard let raw = RecordingWaveformAnalyzer.loadCachedDecibels(for: fileURL) else {
            return nil
        }

        let downsampled = downsample(raw, maxPoints: maxThumbnailPoints)
        cache.setObject(CacheBox(downsampled), forKey: key)
        return downsampled
    }

    static func invalidate(for fileURL: URL) {
        cache.removeObject(forKey: cacheKey(for: fileURL))
    }

    static func invalidateAll() {
        cache.removeAllObjects()
    }

    private static func cacheKey(for fileURL: URL) -> NSString {
        fileURL.standardizedFileURL.path as NSString
    }

    private static func downsample(_ samples: [Float], maxPoints: Int) -> [Float] {
        guard samples.count > maxPoints, maxPoints > 1 else { return samples }

        return (0..<maxPoints).map { index in
            let position = Double(index) / Double(maxPoints - 1) * Double(samples.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(position - Double(lower))
            return samples[lower] + (samples[upper] - samples[lower]) * fraction
        }
    }
}
