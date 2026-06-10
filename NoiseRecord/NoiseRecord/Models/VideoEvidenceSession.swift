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

    init(
        fileName: String,
        filePath: String,
        startedAt: Date,
        endedAt: Date,
        peakDB: Float,
        averageDB: Float,
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
        self.latitude = latitude
        self.longitude = longitude
        self.fileHash = Self.hashFile(at: filePath)
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

    static func hashFile(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
