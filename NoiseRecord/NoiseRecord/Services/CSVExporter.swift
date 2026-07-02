import Foundation

struct MeasurementCSVRow: Sendable {
    let timestamp: Date
    let dbCurrent: Float
    let dbMax: Float
    let dbMin: Float
    let dbAvg: Float
    let leq: Float
    let weighting: String
    let noiseType: String?
}

enum CSVExporter {
    static func exportMeasurementLog(rows: [MeasurementCSVRow]) -> URL? {
        let header = "timestamp,db_current,db_max,db_min,db_avg,leq,weighting,noise_type\n"
        let formatter = ISO8601DateFormatter()
        var csv = header
        for row in rows {
            let type = row.noiseType ?? ""
            csv += "\(formatter.string(from: row.timestamp)),\(row.dbCurrent),\(row.dbMax),\(row.dbMin),\(row.dbAvg),\(row.leq),\(row.weighting),\(type)\n"
        }
        return writeToTempFile(csv, name: "noise_measurement.csv")
    }

    static func exportRecordingSessions(_ sessions: [RecordingSession]) -> URL? {
        let header = "started_at,ended_at,peak_db,average_db,file_name,noise_type\n"
        let formatter = ISO8601DateFormatter()
        var csv = header
        for session in sessions {
            let type = session.noiseType ?? ""
            csv += "\(formatter.string(from: session.startedAt)),\(formatter.string(from: session.endedAt)),\(session.peakDB),\(session.averageDB),\(session.fileName),\(type)\n"
        }
        return writeToTempFile(csv, name: "noise_recordings.csv")
    }

    static func exportSleepSessionLog(session: SleepNoiseSession, rows: [MeasurementCSVRow]) -> URL? {
        let formatter = ISO8601DateFormatter()
        var csv = "session_started,session_ended,overall_leq,noise_floor,peak_db,anomaly_count,grade\n"
        csv += "\(formatter.string(from: session.startedAt)),"
        if let ended = session.endedAt {
            csv += formatter.string(from: ended)
        }
        csv += ",\(session.overallLeq),\(session.noiseFloorDB),\(session.peakDB),\(session.anomalyCount),\(session.grade)\n\n"
        csv += "timestamp,db_current,db_max,db_min,db_avg,leq,weighting,noise_type\n"
        for row in rows {
            let type = row.noiseType ?? ""
            csv += "\(formatter.string(from: row.timestamp)),\(row.dbCurrent),\(row.dbMax),\(row.dbMin),\(row.dbAvg),\(row.leq),\(row.weighting),\(type)\n"
        }
        return writeToTempFile(csv, name: "sleep_noise_session.csv")
    }

    private static func writeToTempFile(_ content: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
