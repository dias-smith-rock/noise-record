import CryptoKit
import Foundation
import SwiftData

@Model
final class RecordingSession {
    var id: UUID
    var fileName: String
    var filePath: String
    var startedAt: Date
    var endedAt: Date
    var peakDB: Float
    var averageDB: Float
    var noiseType: String?
    var fileHash: String?
    var isNew: Bool = false
    var notes: String = ""
    var latitude: Double?
    var longitude: Double?

    init(
        fileName: String,
        filePath: String,
        startedAt: Date,
        endedAt: Date,
        peakDB: Float,
        averageDB: Float,
        noiseType: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.filePath = filePath
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.peakDB = peakDB
        self.averageDB = averageDB
        self.noiseType = noiseType
        self.latitude = latitude
        self.longitude = longitude
        self.fileHash = Self.hashFile(at: filePath)
        self.isNew = true
    }

    var fileURL: URL {
        EvidenceFileResolver.resolveURL(
            storedPath: filePath,
            fileName: fileName,
            folder: .recordings
        )
    }

    var fileExists: Bool {
        EvidenceFileResolver.fileExists(
            storedPath: filePath,
            fileName: fileName,
            folder: .recordings
        )
    }

    var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    var noiseTimeline: VideoNoiseTimeline? {
        VideoNoiseTimelineStore.load(for: fileURL)
    }

    static func hashFile(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
