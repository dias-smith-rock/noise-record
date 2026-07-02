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
    var segmentGroupID: UUID?
    var segmentIndex: Int = 1
    var isSessionRecording: Bool = false
    var sleepSessionID: UUID?

    init(
        fileName: String,
        filePath: String,
        startedAt: Date,
        endedAt: Date,
        peakDB: Float,
        averageDB: Float,
        noiseType: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        segmentGroupID: UUID? = nil,
        segmentIndex: Int = 1,
        isSessionRecording: Bool = false,
        sleepSessionID: UUID? = nil
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
        self.segmentGroupID = segmentGroupID
        self.segmentIndex = segmentIndex
        self.isSessionRecording = isSessionRecording
        self.sleepSessionID = sleepSessionID
        self.fileHash = Self.hashFile(at: filePath)
        self.isNew = true
    }

    var preferredFileURL: URL {
        EvidenceFileResolver.preferredURL(
            storedPath: filePath,
            fileName: fileName,
            folder: .recordings
        )
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
        max(0, endedAt.timeIntervalSince(recordingStartDate))
    }

    /// UI-facing recording start — prefers the timestamp embedded in the file name.
    var recordingStartDate: Date {
        if segmentIndex > 1 {
            return startedAt
        }
        return Self.parseStartDate(from: fileName) ?? startedAt
    }

    var noiseTimeline: VideoNoiseTimeline? {
        VideoNoiseTimelineStore.load(for: fileURL)
    }

    static func hashFile(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Parses `yyyyMMdd_HHmmss` from recording file names such as
    /// `F_20260701_180612.m4a`, `S_20260701_180613.m4a`, or legacy `*_session.m4a` / `*_55dB.m4a`.
    static func parseStartDate(from fileName: String) -> Date? {
        let stem = (fileName as NSString).deletingPathExtension
        let token: String
        if stem.hasPrefix("F_") || stem.hasPrefix("S_") {
            let offset = 2
            guard stem.count >= offset + 15 else { return nil }
            let start = stem.index(stem.startIndex, offsetBy: offset)
            let end = stem.index(start, offsetBy: 15)
            token = String(stem[start..<end])
        } else if stem.count >= 15 {
            token = String(stem.prefix(15))
        } else {
            return nil
        }
        return recordingTimestampFormatter.date(from: token)
    }

    private static let recordingTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
