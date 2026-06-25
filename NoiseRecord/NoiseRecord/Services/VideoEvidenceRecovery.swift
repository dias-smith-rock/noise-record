import AVFoundation
import Foundation
import SwiftData

enum VideoEvidenceRecovery {
    private static let minimumRecoverableBytes: UInt64 = 1024

    /// Scans `Documents/VideoEvidence` for finalized `.mp4` files missing from SwiftData and imports them.
    @MainActor
    static func recoverOrphanedFiles(modelContext: ModelContext) -> Int {
        let directory = EvidenceFileResolver.documentsDirectory
            .appendingPathComponent(EvidenceMediaFolder.videoEvidence.rawValue, isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        let knownNames = Set(
            (try? modelContext.fetch(FetchDescriptor<VideoEvidenceSession>()))?
                .map(\.fileName) ?? []
        )

        var recovered = 0
        for url in entries where url.pathExtension.lowercased() == "mp4" {
            let fileName = url.lastPathComponent
            guard !knownNames.contains(fileName) else { continue }
            guard isRecoverableVideo(at: url) else { continue }

            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let modified = attributes?[.modificationDate] as? Date ?? Date()
            let created = attributes?[.creationDate] as? Date ?? modified

            let session = VideoEvidenceSession(
                fileName: fileName,
                filePath: EvidenceFileResolver.makeRelativePath(from: url),
                startedAt: created,
                endedAt: modified,
                peakDB: 0,
                averageDB: 0
            )
            modelContext.insert(session)
            recovered += 1
        }

        if recovered > 0 {
            try? modelContext.save()
        }
        return recovered
    }

    /// Removes stale `.mp4.part` files left from interrupted writes.
    static func removeStalePartFiles() {
        let directory = EvidenceFileResolver.documentsDirectory
            .appendingPathComponent(EvidenceMediaFolder.videoEvidence.rawValue, isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in entries where url.lastPathComponent.hasSuffix(".mp4.part") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func isRecoverableVideo(at url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values?.fileSize, size >= minimumRecoverableBytes else { return false }
        let asset = AVURLAsset(url: url)
        return asset.isPlayable
    }
}
