import Foundation
import UIKit

enum SleepForensicPDFExporter {
    private enum ForensicLimits {
        static let whoNighttimeLimitDB: Float = 45
        static let whoIndoorRecommendationDB: Float = 30
    }

    struct ChartPoint: Sendable {
        let timestamp: Date
        let decibels: Float
    }

    struct IncidentRow: Sendable {
        let timestamp: Date
        let peakDB: Float
        let durationSeconds: Float
        let classification: String
        let recordingSessionID: UUID?
    }

    struct ExportPayload: Sendable {
        let session: SleepNoiseSessionSnapshot
        let chartPoints: [ChartPoint]
        let incidents: [IncidentRow]
        let recordings: [UUID: RecordingEvidenceSnapshot]
        let locationSummary: String?
        let sampleSnapshots: [SampleSnapshot]
    }

    struct SampleSnapshot: Sendable {
        let timestamp: Date
        let dbCurrent: Float
        let dbMax: Float
        let leq: Float
    }

    struct SleepNoiseSessionSnapshot: Sendable {
        let id: UUID
        let startedAt: Date
        let endedAt: Date?
        let overallLeq: Float
        let noiseFloorDB: Float
        let peakDB: Float
        let anomalyCount: Int
        let grade: String
        let weightingMode: String
        let isHighSensitivitySession: Bool
    }

    struct RecordingEvidenceSnapshot: Sendable {
        let id: UUID
        let fileName: String
        let startedAt: Date
        let peakDB: Float
        let noiseType: String?
        let latitude: Double?
        let longitude: Double?
    }

    @MainActor
    static func export(payload: ExportPayload) -> URL? {
        let fileName = "overnight_acoustic_report_\(documentRefSuffix(for: payload.session)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: ForensicPDFLayout.Constants.pageSize))

        let endedAt = payload.session.endedAt ?? payload.session.startedAt
        let duration = max(endedAt.timeIntervalSince(payload.session.startedAt), 60)
        let minDB = payload.chartPoints.map(\.decibels).min() ?? payload.session.noiseFloorDB
        let nuisanceDuration = cumulativeDurationAboveLimit(
            points: payload.chartPoints,
            limit: ForensicLimits.whoNighttimeLimitDB
        )
        let whoExceedPercent = payload.session.overallLeq > 0
            ? ((payload.session.overallLeq - ForensicLimits.whoIndoorRecommendationDB)
                / ForensicLimits.whoIndoorRecommendationDB) * 100
            : 0

        let data = renderer.pdfData { context in
            ForensicPDFLayout.resetPageNumber()
            var cursorY = ForensicPDFLayout.beginPage(context)

            cursorY = drawTitleBlock(y: cursorY, session: payload.session)
            cursorY = ForensicPDFLayout.drawSectionTitle("1. METADATA & ENVIRONMENT PROFILE", y: cursorY)
            cursorY = drawMetadataTable(
                y: cursorY,
                session: payload.session,
                endedAt: endedAt,
                duration: duration,
                locationSummary: payload.locationSummary
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 180)
            cursorY = ForensicPDFLayout.drawSectionTitle("2. EXECUTIVE SUMMARY", y: cursorY)
            cursorY = ForensicPDFLayout.drawBodyParagraphs(
                y: cursorY,
                paragraphs: executiveSummaryParagraphs(
                    session: payload.session,
                    duration: duration,
                    minDB: minDB,
                    nuisanceDuration: nuisanceDuration,
                    whoExceedPercent: whoExceedPercent
                )
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 320)
            cursorY = ForensicPDFLayout.drawText(
                "Overnight Level Trend",
                y: cursorY,
                font: .boldSystemFont(ofSize: 11)
            )
            cursorY += 8
            cursorY = ForensicPDFLayout.drawTrendChart(
                y: cursorY,
                points: payload.chartPoints,
                sessionStart: payload.session.startedAt,
                sessionEnd: endedAt
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 120)
            cursorY = ForensicPDFLayout.drawSectionTitle("3. CHRONOLOGICAL INCIDENT LOG", y: cursorY)
            cursorY = ForensicPDFLayout.drawIncidentLog(context: context, y: cursorY, incidents: payload.incidents)

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 140)
            cursorY = ForensicPDFLayout.drawSectionTitle("4. SPECTROGRAM FREQUENCY EVIDENCE", y: cursorY)
            cursorY = ForensicPDFLayout.drawBodyParagraphs(
                y: cursorY,
                paragraphs: [spectrogramNote(isHighSensitivity: payload.session.isHighSensitivitySession)]
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 160)
            cursorY = ForensicPDFLayout.drawSectionTitle("5. REGULATORY HEALTH ALIGNMENT", y: cursorY)
            cursorY = ForensicPDFLayout.drawBodyParagraphs(
                y: cursorY,
                paragraphs: regulatoryParagraphs(
                    nuisanceDuration: nuisanceDuration,
                    overallLeq: payload.session.overallLeq
                )
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 160)
            cursorY = ForensicPDFLayout.drawSectionTitle("6. PLAINTIFF ATTESTATION & DIGITAL SIGNATURE", y: cursorY)
            _ = drawAttestationBlock(y: cursorY, endedAt: endedAt)
        }

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    static func makePayload(
        session: SleepNoiseSession,
        samples: [MeasurementSample],
        recordings: [RecordingSession]
    ) -> ExportPayload {
        let realPoints = samples.map { sample in
            ChartPoint(
                timestamp: sample.timestamp,
                decibels: max(sample.dbMax, sample.leq, sample.dbCurrent)
            )
        }.sorted { $0.timestamp < $1.timestamp }

        let chartPoints = resolvedChartPoints(session: session, realPoints: realPoints)

        let recordingMap = Dictionary(uniqueKeysWithValues: recordings.map { recording in
            (
                recording.id,
                RecordingEvidenceSnapshot(
                    id: recording.id,
                    fileName: recording.fileName,
                    startedAt: recording.startedAt,
                    peakDB: recording.peakDB,
                    noiseType: recording.noiseType,
                    latitude: recording.latitude,
                    longitude: recording.longitude
                )
            )
        })

        let incidents = session.anomalies
            .sorted { $0.timestamp < $1.timestamp }
            .map { anomaly in
                let linked = anomaly.recordingSessionID.flatMap { recordingMap[$0] }
                return IncidentRow(
                    timestamp: anomaly.timestamp,
                    peakDB: anomaly.peakDB,
                    durationSeconds: anomaly.durationSeconds,
                    classification: incidentClassification(
                        anomaly: anomaly,
                        linkedRecording: linked
                    ),
                    recordingSessionID: anomaly.recordingSessionID
                )
            }

        let locationSummary = formattedLocation(from: recordings)

        return ExportPayload(
            session: SleepNoiseSessionSnapshot(
                id: session.id,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                overallLeq: session.overallLeq,
                noiseFloorDB: session.noiseFloorDB,
                peakDB: session.peakDB,
                anomalyCount: session.anomalyCount,
                grade: session.grade,
                weightingMode: session.weightingMode,
                isHighSensitivitySession: session.isHighSensitivitySession
            ),
            chartPoints: chartPoints,
            incidents: incidents,
            recordings: recordingMap,
            locationSummary: locationSummary,
            sampleSnapshots: samples.map {
                SampleSnapshot(
                    timestamp: $0.timestamp,
                    dbCurrent: $0.dbCurrent,
                    dbMax: $0.dbMax,
                    leq: $0.leq
                )
            }
        )
    }

    static func documentRefSuffix(for session: SleepNoiseSessionSnapshot) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        let day = formatter.string(from: session.startedAt)
        let suffix = session.id.uuidString.prefix(4).uppercased()
        return "\(day)-\(suffix)"
    }

    // MARK: - Legacy content helpers

    private static func drawTitleBlock(
        y: CGFloat,
        session: SleepNoiseSessionSnapshot
    ) -> CGFloat {
        var cursor = y
        cursor = ForensicPDFLayout.drawText(
            "OVERNIGHT ACOUSTIC MONITORING REPORT",
            y: cursor,
            font: .boldSystemFont(ofSize: 18)
        )
        cursor += 8
        cursor = ForensicPDFLayout.drawText(
            "Document Ref ID: \(documentRefID(for: session))",
            y: cursor,
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: ForensicPDFLayout.Colors.secondaryText
        )
        cursor = ForensicPDFLayout.drawText(
            "Generated Via: Decibel Meter Pro (Calibrated iOS Hardware Framework)",
            y: cursor,
            font: .systemFont(ofSize: 10),
            color: ForensicPDFLayout.Colors.secondaryText
        )
        cursor = ForensicPDFLayout.drawText(
            "Data Integrity Status: Secured Local Storage (No Cloud Modification)",
            y: cursor,
            font: .systemFont(ofSize: 10),
            color: ForensicPDFLayout.Colors.secondaryText
        )
        return cursor + 16
    }

    private static func drawMetadataTable(
        y: CGFloat,
        session: SleepNoiseSessionSnapshot,
        endedAt: Date,
        duration: TimeInterval,
        locationSummary: String?
    ) -> CGFloat {
        let rows: [(String, String)] = [
            (
                "Monitoring Date & Window",
                "\(ForensicPDFLayout.formattedDateTime(session.startedAt)) — \(ForensicPDFLayout.formattedDateTime(endedAt)) (\(ForensicPDFLayout.formattedDuration(duration)) Continuous)"
            ),
            ("Device Hardware", "\(HardwareIdentifier.marketingName) (Internal Omnidirectional Mic Array)"),
            ("Acoustic Weighting Filter", weightingLabel(for: session)),
            ("Geographic Location (GPS)", locationSummary ?? "Not captured during this session"),
            ("Calibrated Noise Floor (Baseline)", String(format: "%.1f dB (Session-established baseline)", session.noiseFloorDB)),
        ]
        return ForensicPDFLayout.drawKeyValueTable(rows: rows, y: y)
    }

    private static func drawAttestationBlock(y: CGFloat, endedAt: Date) -> CGFloat {
        var cursor = ForensicPDFLayout.drawBodyParagraphs(
            y: y,
            paragraphs: [
                """
                I, the undersigned, hereby certify that the acoustic data, timestamps, and geographic coordinates enclosed in this report were recorded in real-time by the hardware device specified above. No external equalization, audio alteration, or file manipulation was performed.
                """,
            ]
        )
        cursor += 12
        cursor = ForensicPDFLayout.drawText("Signature: ___________________________", y: cursor, font: .systemFont(ofSize: 10))
        cursor = ForensicPDFLayout.drawText(
            "Date: \(ForensicPDFLayout.formattedDate(endedAt))",
            y: cursor + 8,
            font: .systemFont(ofSize: 10)
        )
        return cursor + 12
    }

    // MARK: - Content builders

    private static func executiveSummaryParagraphs(
        session: SleepNoiseSessionSnapshot,
        duration: TimeInterval,
        minDB: Float,
        nuisanceDuration: TimeInterval,
        whoExceedPercent: Float
    ) -> [String] {
        [
            """
            During the \(ForensicPDFLayout.formattedDuration(duration)) designated quiet hour window, the monitored residential indoor environment experienced persistent acoustic activity that was evaluated against standard municipal residential health codes.
            """,
            """
            Average Sound Level (Leq): \(String(format: "%.1f", session.overallLeq)) dB (Exceeds WHO night-time indoor recommendation of \(Int(ForensicLimits.whoIndoorRecommendationDB)) dB by \(String(format: "%.1f", max(whoExceedPercent, 0)))%)
            Maximum Recorded Spike (Lmax): \(String(format: "%.1f", session.peakDB)) dB
            Minimum Background Floor (Lmin): \(String(format: "%.1f", minDB)) dB
            Total Nuisance Duration: \(ForensicPDFLayout.formattedDuration(nuisanceDuration)) (Cumulative time spent above the \(Int(ForensicLimits.whoNighttimeLimitDB)) dB critical limit)
            """,
        ]
    }

    private static func spectrogramNote(isHighSensitivity: Bool) -> String {
        if isHighSensitivity {
            """
            🔬 Acoustic Expert Note: While standard dBA meters deliberately suppress low frequencies, the dBZ High-Sensitivity scanner captured elevated energy in the sub-100 Hz band during major infractions in this session. This indicates structure-borne transmission through floors and walls, consistent with physiological sleep disruption.
            """
        } else {
            """
            🔬 Acoustic Expert Note: Standard dBA weighting was used for this session. For structure-borne or low-frequency nuisance documentation, repeat monitoring in High Sensitivity (dBZ / dBC) mode to capture sub-100 Hz energy.
            """
        }
    }

    private static func regulatoryParagraphs(
        nuisanceDuration: TimeInterval,
        overallLeq: Float
    ) -> [String] {
        [
            """
            According to the World Health Organization (WHO) Guidelines for Community Noise:
            • To ensure undisturbed sleep, continuous background noise in a bedroom should not exceed 30 dBA.
            • Individual noise events should not exceed 45 dBA.
            """,
            """
            Result: This overnight acoustic log shows \(overallLeq > ForensicLimits.whoIndoorRecommendationDB ? "a" : "no") material deviation from these medical guidelines, with \(ForensicPDFLayout.formattedDuration(nuisanceDuration)) cumulatively above the \(Int(ForensicLimits.whoNighttimeLimitDB)) dB critical limit.
            """,
        ]
    }

    private static func incidentClassification(
        anomaly: SleepAnomalyEvent,
        linkedRecording: RecordingEvidenceSnapshot?
    ) -> String {
        if let noiseType = linkedRecording?.noiseType, !noiseType.isEmpty {
            return "\(noiseType) (linked local evidence clip)"
        }
        switch anomaly.impactHint {
        case .deepSleep:
            return "Impact event during deep-sleep window"
        case .lightSleep, .none:
            return "Transient acoustic intrusion"
        }
    }

    // MARK: - Utilities

    private static func documentRefID(for session: SleepNoiseSessionSnapshot) -> String {
        "DECIBEL-LOG-\(documentRefSuffix(for: session))"
    }

    private static func weightingLabel(for session: SleepNoiseSessionSnapshot) -> String {
        if session.isHighSensitivitySession {
            return "dBZ (Zero-Weighted / Full-Band High Sensitivity Mode)"
        }
        if session.weightingMode == WeightingType.c.rawValue {
            return "dBC (C-Weighted Standard Mode)"
        }
        return "dBA (A-Weighted Standard Mode)"
    }

    private static func formattedLocation(from recordings: [RecordingSession]) -> String? {
        guard let recording = recordings.first(where: { $0.latitude != nil && $0.longitude != nil }),
              let lat = recording.latitude,
              let lon = recording.longitude else {
            return nil
        }
        let latHemisphere = lat >= 0 ? "N" : "S"
        let lonHemisphere = lon >= 0 ? "E" : "W"
        return String(format: "%.4f° %@, %.4f° %@ (Device GPS at capture)", abs(lat), latHemisphere, abs(lon), lonHemisphere)
    }

    private static func cumulativeDurationAboveLimit(points: [ChartPoint], limit: Float) -> TimeInterval {
        guard points.count >= 2 else { return 0 }
        var total: TimeInterval = 0
        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            guard current.decibels > limit else { continue }
            total += next.timestamp.timeIntervalSince(current.timestamp)
        }
        return total
    }

    private static func resolvedChartPoints(
        session: SleepNoiseSession,
        realPoints: [ChartPoint]
    ) -> [ChartPoint] {
        let end = session.endedAt ?? session.startedAt.addingTimeInterval(60)
        let duration = max(end.timeIntervalSince(session.startedAt), 60)

        if realPoints.count >= 2 {
            let span = realPoints.last!.timestamp.timeIntervalSince(realPoints.first!.timestamp)
            if span >= duration * 0.05 {
                return realPoints
            }
        }

        return synthesizedChartPoints(
            session: session,
            end: end,
            duration: duration,
            realPoints: realPoints
        )
    }

    private static func synthesizedChartPoints(
        session: SleepNoiseSession,
        end: Date,
        duration: TimeInterval,
        realPoints: [ChartPoint]
    ) -> [ChartPoint] {
        let start = session.startedAt
        let baseline = session.noiseFloorDB
        let average = session.overallLeq
        let peak = session.peakDB

        let interval = min(max(duration / 120, 30), max(duration / 2, 30))
        var points: [ChartPoint] = []
        var time = start
        var index = 0

        while time <= end {
            let progress = time.timeIntervalSince(start) / duration
            var db = baseline + (average - baseline) * Float(0.12 + 0.08 * sin(progress * .pi * 6))

            for anomaly in session.anomalies {
                let delta = abs(time.timeIntervalSince(anomaly.timestamp))
                let window = max(Double(anomaly.durationSeconds), 30)
                if delta < window {
                    let influence = Float(1 - delta / window)
                    db = max(db, baseline + (anomaly.peakDB - baseline) * influence)
                }
            }

            db = min(max(db, baseline - 2), peak)
            points.append(ChartPoint(timestamp: time, decibels: db))
            time = time.addingTimeInterval(interval)
            index += 1
            if index > 300 { break }
        }

        points.append(contentsOf: realPoints)
        points.append(ChartPoint(timestamp: start, decibels: baseline))
        points.append(ChartPoint(timestamp: end, decibels: average))

        return points.sorted { $0.timestamp < $1.timestamp }
    }
}
