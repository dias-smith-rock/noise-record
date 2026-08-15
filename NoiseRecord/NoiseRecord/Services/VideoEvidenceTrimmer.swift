import AVFoundation
import Foundation

enum VideoEvidenceTrimmerError: LocalizedError {
    case exportSessionUnavailable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .exportSessionUnavailable:
            return "Could not create video export session."
        case .exportFailed(let message):
            return message
        }
    }
}

/// Trims evidence MP4s to a free-tier duration and keeps the noise timeline aligned.
enum VideoEvidenceTrimmer {
    static func trimIfNeeded(
        fileURL: URL,
        maxDuration: TimeInterval
    ) async throws -> (url: URL, didTrim: Bool) {
        guard maxDuration > 0, maxDuration.isFinite else {
            return (fileURL, false)
        }

        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > maxDuration + 0.15 else {
            return (fileURL, false)
        }

        let trimmedURL = try await exportTrimmedCopy(
            asset: asset,
            sourceURL: fileURL,
            maxDuration: maxDuration
        )

        try replaceFile(at: fileURL, with: trimmedURL)
        trimTimeline(for: fileURL, maxDuration: maxDuration)
        return (fileURL, true)
    }

    private static func exportTrimmedCopy(
        asset: AVURLAsset,
        sourceURL: URL,
        maxDuration: TimeInterval
    ) async throws -> URL {
        let tempURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("trim_\(UUID().uuidString).mp4")

        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEvidenceTrimmerError.exportSessionUnavailable
        }

        session.outputURL = tempURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: maxDuration, preferredTimescale: 600)
        )

        await session.export()

        switch session.status {
        case .completed:
            return tempURL
        case .failed, .cancelled:
            try? FileManager.default.removeItem(at: tempURL)
            throw VideoEvidenceTrimmerError.exportFailed(
                session.error?.localizedDescription ?? "Video trim failed."
            )
        default:
            try? FileManager.default.removeItem(at: tempURL)
            throw VideoEvidenceTrimmerError.exportFailed("Video trim did not complete.")
        }
    }

    private static func replaceFile(at original: URL, with temp: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: original.path) {
            try fm.removeItem(at: original)
        }
        try fm.moveItem(at: temp, to: original)
    }

    private static func trimTimeline(for videoURL: URL, maxDuration: TimeInterval) {
        guard let timeline = VideoNoiseTimelineStore.load(for: videoURL) else { return }
        let clipped = timeline.samples.filter { $0.time <= maxDuration + 0.05 }
        guard !clipped.isEmpty else {
            VideoNoiseTimelineStore.remove(for: videoURL)
            return
        }

        var next = VideoNoiseTimeline(
            weighting: timeline.weighting,
            samples: clipped,
            source: timeline.source ?? .live,
            normalized: false
        )
        if let normalized = next.normalized(to: maxDuration, source: next.source ?? .live) {
            next = normalized
        }
        try? VideoNoiseTimelineStore.save(next, for: videoURL)
    }
}
