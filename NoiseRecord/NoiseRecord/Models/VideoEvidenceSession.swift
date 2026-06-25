import CryptoKit
import Foundation
import SwiftData

@Model
final class VideoEvidenceSession {
    var id: UUID
    var fileName: String
    var filePath: String
    var startedAt: Date
    var endedAt: Date
    var peakDB: Float
    var averageDB: Float
    var latitude: Double?
    var longitude: Double?
    var fileHash: String?
    var isNew: Bool = false
    var segmentGroupID: UUID?
    var segmentIndex: Int = 1

    init(
        fileName: String,
        filePath: String,
        startedAt: Date,
        endedAt: Date,
        peakDB: Float,
        averageDB: Float,
        latitude: Double? = nil,
        longitude: Double? = nil,
        segmentGroupID: UUID? = nil,
        segmentIndex: Int = 1
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.filePath = filePath
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.peakDB = peakDB
        self.averageDB = averageDB
        self.latitude = latitude
        self.longitude = longitude
        self.segmentGroupID = segmentGroupID
        self.segmentIndex = segmentIndex
        self.fileHash = Self.hashFile(at: filePath)
        self.isNew = true
    }

    var fileURL: URL {
        EvidenceFileResolver.resolveURL(
            storedPath: filePath,
            fileName: fileName,
            folder: .videoEvidence
        )
    }

    var fileExists: Bool {
        EvidenceFileResolver.fileExists(
            storedPath: filePath,
            fileName: fileName,
            folder: .videoEvidence
        )
    }

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    var noiseTimeline: VideoNoiseTimeline? {
        VideoNoiseTimelineStore.load(for: fileURL)
    }

    static func hashFile(at path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let resolved = FileManager.default.fileExists(atPath: path)
            ? url
            : EvidenceFileResolver.resolveURL(
                storedPath: path,
                fileName: url.lastPathComponent,
                folder: .videoEvidence
            )
        guard let handle = try? FileHandle(forReadingFrom: resolved) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunkSize = 1024 * 1024
        while true {
            let data = handle.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
