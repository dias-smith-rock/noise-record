import Foundation
import SwiftData

// MARK: - Schema versions

/// Pre–sleep-monitor schema (no sleep entities, no sleepSessionID fields).
enum NoiseRecordSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            RecordingSession.self,
            MeasurementSample.self,
            VideoEvidenceSession.self,
        ]
    }
}

/// Adds sleep monitoring entities and optional sleep-session links on existing models.
enum NoiseRecordSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            RecordingSession.self,
            MeasurementSample.self,
            VideoEvidenceSession.self,
            SleepNoiseSession.self,
            SleepAnomalyEvent.self,
        ]
    }
}

enum NoiseRecordMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            NoiseRecordSchemaV1.self,
            NoiseRecordSchemaV2.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(
                fromVersion: NoiseRecordSchemaV1.self,
                toVersion: NoiseRecordSchemaV2.self
            ),
        ]
    }
}

// MARK: - Store location

enum SwiftDataStoreLocation {
    static let filename = "NoiseRecord.store"

    static var url: URL {
        URL.applicationSupportDirectory.appending(path: filename)
    }

    static func removeStoreFiles() {
        let base = url
        let candidates = [
            base,
            URL(fileURLWithPath: base.path() + "-shm"),
            URL(fileURLWithPath: base.path() + "-wal"),
        ]
        let fileManager = FileManager.default
        for fileURL in candidates where fileManager.fileExists(atPath: fileURL.path()) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
