import Foundation

struct WaveformThumbnailData: Sendable {
    let timeline: VideoNoiseTimeline
    let playbackDuration: TimeInterval
}

/// In-memory cache for list waveform thumbnails. Disk is read at most once per file path.
enum WaveformThumbnailCache {
    private final class CacheBox: NSObject {
        let data: WaveformThumbnailData
        init(_ data: WaveformThumbnailData) { self.data = data }
    }

    private static let cache = NSCache<NSString, CacheBox>()
    private static let maxThumbnailPoints = 120

    static func thumbnail(for fileURL: URL, alternateURLs: [URL] = []) -> WaveformThumbnailData? {
        let key = cacheKey(for: fileURL, alternateURLs: alternateURLs)
        if let cached = cache.object(forKey: key)?.data {
            return cached
        }

        guard let raw = RecordingWaveformAnalyzer.loadCachedTimelineForThumbnail(
            for: fileURL,
            alternateURLs: alternateURLs
        ) else {
            return nil
        }

        let playbackDuration = max(raw.timelineDuration, 0.001)
        let downsampled = downsample(raw.samples, maxPoints: maxThumbnailPoints)
        let timeline = VideoNoiseTimeline(
            weighting: raw.weighting,
            samples: downsampled,
            source: raw.source ?? .offline,
            normalized: raw.normalized ?? false
        )
        let data = WaveformThumbnailData(timeline: timeline, playbackDuration: playbackDuration)
        cache.setObject(CacheBox(data), forKey: key)
        return data
    }

    static func invalidate(for fileURL: URL, alternateURLs: [URL] = []) {
        cache.removeObject(forKey: cacheKey(for: fileURL, alternateURLs: alternateURLs))
    }

    static func invalidateAll() {
        cache.removeAllObjects()
    }

    private static func cacheKey(for fileURL: URL, alternateURLs: [URL]) -> NSString {
        let paths = ([fileURL] + alternateURLs)
            .map { $0.standardizedFileURL.path }
            .sorted()
            .joined(separator: "|")
        return paths as NSString
    }

    private static func downsample(_ samples: [VideoNoiseSample], maxPoints: Int) -> [VideoNoiseSample] {
        guard samples.count > maxPoints, maxPoints > 1 else { return samples }

        return (0..<maxPoints).map { index in
            let position = Double(index) / Double(maxPoints - 1) * Double(samples.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = position - Double(lower)
            let lowerSample = samples[lower]
            let upperSample = samples[upper]
            let time = lowerSample.time + (upperSample.time - lowerSample.time) * fraction
            let decibel = lowerSample.decibel + Float(fraction) * (upperSample.decibel - lowerSample.decibel)
            return VideoNoiseSample(time: time, decibel: decibel)
        }
    }
}
