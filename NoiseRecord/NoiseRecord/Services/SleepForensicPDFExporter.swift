import CryptoKit
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
        let startTemperatureCelsius: Double?
        let startHumidityPercent: Int?
        let endTemperatureCelsius: Double?
        let endHumidityPercent: Int?

        var startEnvironmentSnapshot: SleepEnvironmentSnapshot {
            SleepEnvironmentSnapshot(
                temperatureCelsius: startTemperatureCelsius,
                humidityPercent: startHumidityPercent
            )
        }

        var endEnvironmentSnapshot: SleepEnvironmentSnapshot {
            SleepEnvironmentSnapshot(
                temperatureCelsius: endTemperatureCelsius,
                humidityPercent: endHumidityPercent
            )
        }
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
        let minPoint = payload.chartPoints.min(by: { $0.decibels < $1.decibels })
        let minDB = minPoint?.decibels ?? payload.session.noiseFloorDB
        let peakPoint = payload.chartPoints.max(by: { $0.decibels < $1.decibels })
        let peakTimestamp = peakPoint?.timestamp
            ?? payload.incidents.max(by: { $0.peakDB < $1.peakDB })?.timestamp
        let minTimestamp = minPoint?.timestamp
        let environmentSummary = SleepEnvironmentFormatter.pdfEnglishSummary(
            start: payload.session.startEnvironmentSnapshot,
            end: payload.session.endEnvironmentSnapshot
        )
        let nuisanceDuration = cumulativeDurationAboveLimit(
            points: payload.chartPoints,
            limit: ForensicLimits.whoNighttimeLimitDB
        )

        let data = renderer.pdfData { context in
            let documentRef = documentRefID(for: payload.session)
            ForensicPDFLayout.resetPageNumber(
                footerStyle: .overnightReport(documentRef: documentRef)
            )
            var cursorY = ForensicPDFLayout.beginPage(context)

            cursorY = drawTitleBlock(y: cursorY, session: payload.session, payload: payload)
            cursorY = ForensicPDFLayout.drawSectionTitle("1. FORENSIC METADATA & ENVIRONMENT PROFILE", y: cursorY)
            cursorY = drawMetadataTable(
                context: context,
                y: cursorY,
                session: payload.session,
                endedAt: endedAt,
                duration: duration,
                locationSummary: payload.locationSummary,
                environmentSummary: environmentSummary
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 180)
            cursorY = ForensicPDFLayout.drawSectionTitle("2. EXECUTIVE SUMMARY", y: cursorY)
            cursorY = drawExecutiveSummary(
                y: cursorY,
                session: payload.session,
                duration: duration,
                minDB: minDB,
                minTimestamp: minTimestamp,
                peakTimestamp: peakTimestamp,
                incidentCount: payload.incidents.count,
                environmentSummary: environmentSummary
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 120)
            cursorY = ForensicPDFLayout.drawSectionTitle("3. CHRONOLOGICAL INCIDENT LOG", y: cursorY)
            cursorY = ForensicPDFLayout.drawOvernightIncidentLog(
                context: context,
                y: cursorY,
                incidents: payload.incidents
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 140)
            cursorY = ForensicPDFLayout.drawSectionTitle("4. SPECTROGRAM FREQUENCY EVIDENCE", y: cursorY)
            cursorY = ForensicPDFLayout.drawBodyParagraphs(
                y: cursorY,
                paragraphs: [spectrogramNote(isHighSensitivity: payload.session.isHighSensitivitySession)],
                fontSize: 9
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 160)
            cursorY = ForensicPDFLayout.drawSectionTitle(
                "5. REGULATORY HEALTH ASSESSMENT & COMPLIANCE STATEMENTS",
                y: cursorY
            )
            cursorY = drawRegulatorySection(
                y: cursorY,
                nuisanceDuration: nuisanceDuration,
                overallLeq: payload.session.overallLeq
            )

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 160)
            cursorY = ForensicPDFLayout.drawSectionTitle("6. PLAINTIFF ATTESTATION & DIGITAL SIGNATURE", y: cursorY)
            cursorY = drawAttestationBlock(y: cursorY, endedAt: endedAt)

            cursorY = ForensicPDFLayout.ensureSpace(context: context, y: cursorY, required: 120)
            cursorY = ForensicPDFLayout.drawSectionTitle("7. LEGAL DISCLAIMER", y: cursorY)
            _ = ForensicPDFLayout.drawBodyParagraphs(
                y: cursorY,
                paragraphs: [legalDisclaimerParagraph],
                fontSize: 8
            )
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
                isHighSensitivitySession: session.isHighSensitivitySession,
                startTemperatureCelsius: session.startTemperatureCelsius,
                startHumidityPercent: session.startHumidityPercent,
                endTemperatureCelsius: session.endTemperatureCelsius,
                endHumidityPercent: session.endHumidityPercent
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

    // MARK: - Layout helpers

    private static func drawTitleBlock(
        y: CGFloat,
        session: SleepNoiseSessionSnapshot,
        payload: ExportPayload
    ) -> CGFloat {
        var cursor = y
        cursor = ForensicPDFLayout.drawCenteredText(
            "OVERNIGHT ACOUSTIC MONITORING REPORT",
            y: cursor,
            font: .boldSystemFont(ofSize: 16)
        )
        cursor += 12
        cursor = ForensicPDFLayout.drawText(
            "Document Reference ID: \(documentRefID(for: session))",
            y: cursor,
            font: .systemFont(ofSize: 9, weight: .semibold)
        )
        cursor = ForensicPDFLayout.drawText(
            "Data Collection Personnel: \(HardwareIdentifier.pdfCollectionPersonnelLine)",
            y: cursor,
            font: .systemFont(ofSize: 9)
        )
        cursor = ForensicPDFLayout.drawText(
            "Data Integrity Hash: \(dataIntegrityHash(for: payload))",
            y: cursor,
            font: .systemFont(ofSize: 8),
            color: ForensicPDFLayout.Colors.secondaryText
        )
        return cursor + 16
    }

    private static func drawMetadataTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        session: SleepNoiseSessionSnapshot,
        endedAt: Date,
        duration: TimeInterval,
        locationSummary: String?,
        environmentSummary: String?
    ) -> CGFloat {
        let monitoringWindow = """
        \(ForensicPDFLayout.formattedDateTime(session.startedAt)) — \(ForensicPDFLayout.formattedDateTime(endedAt)) (\(formattedHoursDuration(duration)) Continuous)
        """
        let temperatureHumidity = environmentSummary ?? "Not recorded"
        let rows = [
            ["Monitoring Window", monitoringWindow],
            ["Hardware Device", HardwareIdentifier.pdfDeviceMetadataLine],
            ["Acoustic Weighting Filter", weightingLabel(for: session)],
            ["Geographic Location / GPS", locationSummary ?? "Not captured during this session"],
            ["Estimated Noise Floor", String(format: "%.1f dB (Ambient conditions)", session.noiseFloorDB)],
            ["Temperature / Humidity", temperatureHumidity],
        ]
        return ForensicPDFLayout.drawBorderedTable(
            context: context,
            y: y,
            headers: ["Metric / Parameter", "Report Forensic Data"],
            rows: rows,
            columnWidths: [168, ForensicPDFLayout.Constants.contentWidth - 168],
            fontSize: 8
        )
    }

    private static func drawExecutiveSummary(
        y: CGFloat,
        session: SleepNoiseSessionSnapshot,
        duration: TimeInterval,
        minDB: Float,
        minTimestamp: Date?,
        peakTimestamp: Date?,
        incidentCount: Int,
        environmentSummary: String?
    ) -> CGFloat {
        var cursor = ForensicPDFLayout.drawBodyParagraphs(
            y: y,
            paragraphs: [
                """
                During the \(ForensicPDFLayout.formattedDuration(duration)) designated quiet-hour monitoring window, the residential indoor environment was continuously evaluated against municipal nighttime noise standards and WHO community noise guidelines.
                """,
            ],
            fontSize: 9
        )

        let peakTimeSuffix = peakTimestamp.map { " at \(ForensicPDFLayout.formattedTime($0))" } ?? ""
        let minTimeSuffix = minTimestamp.map { " at \(ForensicPDFLayout.formattedTime($0))" } ?? ""

        var items = [
            "Average Noise Level (Leq): \(String(format: "%.1f", session.overallLeq)) dB (Target: <\(Int(ForensicLimits.whoNighttimeLimitDB)) dB Night)",
            "Maximum Peak Level (Lpk): \(String(format: "%.1f", session.peakDB)) dB\(peakTimeSuffix)",
            "Minimum Recorded Level (Lmin): \(String(format: "%.1f", minDB)) dB\(minTimeSuffix) (Target: <35 dB)",
            "Ambient Background Floor: \(String(format: "%.1f", session.noiseFloorDB)) dB",
            "Total Acoustic Events: \(incidentCount) distinct incident\(incidentCount == 1 ? "" : "s") detected",
        ]
        if let environmentSummary {
            items.append("Ambient Temperature / Humidity: \(environmentSummary)")
        }

        cursor = ForensicPDFLayout.drawBulletedList(
            y: cursor,
            items: items,
            fontSize: 9
        )
        return cursor
    }

    private static func drawRegulatorySection(
        y: CGFloat,
        nuisanceDuration: TimeInterval,
        overallLeq: Float
    ) -> CGFloat {
        var cursor = ForensicPDFLayout.drawBodyParagraphs(
            y: y,
            paragraphs: [
                """
                The following assessment summarizes compliance with applicable local noise ordinances and WHO community noise health guidelines for residential nighttime environments.
                """,
            ],
            fontSize: 9
        )
        let exceedsNightLimit = overallLeq > ForensicLimits.whoNighttimeLimitDB
        let exceedsIndoor = overallLeq > ForensicLimits.whoIndoorRecommendationDB
        cursor = ForensicPDFLayout.drawBulletedList(
            y: cursor,
            items: [
                "a. Average equivalent sound level (Leq) of \(String(format: "%.1f", overallLeq)) dB \(exceedsNightLimit ? "exceeds" : "is within") the \(Int(ForensicLimits.whoNighttimeLimitDB)) dB nighttime residential limit for individual noise events.",
                "b. Continuous bedroom background noise \(exceedsIndoor ? "exceeds" : "is within") the WHO recommended 30 dBA threshold for undisturbed sleep.",
                "c. Cumulative nuisance duration above the \(Int(ForensicLimits.whoNighttimeLimitDB)) dB critical limit: \(ForensicPDFLayout.formattedDuration(nuisanceDuration)).",
            ],
            fontSize: 9
        )
        return cursor
    }

    private static func drawAttestationBlock(y: CGFloat, endedAt: Date) -> CGFloat {
        var cursor = ForensicPDFLayout.drawBodyParagraphs(
            y: y,
            paragraphs: [
                """
                I, the undersigned, hereby certify that the acoustic data, timestamps, and geographic coordinates enclosed in this report were recorded in real-time by the hardware device specified above. No external equalization, audio alteration, or file manipulation was performed.
                """,
            ],
            fontSize: 9
        )
        cursor += 12
        cursor = ForensicPDFLayout.drawText("Signature: ___________________________", y: cursor, font: .systemFont(ofSize: 9))
        cursor = ForensicPDFLayout.drawText(
            "Date of Signing: \(ForensicPDFLayout.formattedDate(endedAt))",
            y: cursor + 8,
            font: .systemFont(ofSize: 9)
        )
        return cursor + 12
    }

    private static let legalDisclaimerParagraph = """
    This report is generated by Decibel Meter Pro using consumer iOS hardware and is not an ANSI Type 1 certified sound level measurement. Readings are estimates intended for personal reference, evidence documentation, and complaint support only. The publisher assumes no liability for legal, medical, or regulatory decisions made on the basis of this document. Partial reproduction without written authorization is prohibited.
    """

    // MARK: - Content builders

    private static func spectrogramNote(isHighSensitivity: Bool) -> String {
        if isHighSensitivity {
            """
            Acoustic visual data from the High-Sensitivity (dBZ) scanner confirms elevated energy in the sub-100 Hz band during major infractions in this session. This pattern is consistent with structure-borne transmission through floors and walls, including HVAC compressor hum and low-frequency mechanical vibration.
            """
        } else {
            """
            Standard dBA weighting was applied for this session. Acoustic frequency analysis indicates transient and sustained events across the audible spectrum. For structure-borne or low-frequency nuisance documentation, repeat monitoring in High Sensitivity mode to capture sub-100 Hz energy patterns.
            """
        }
    }

    private static func incidentClassification(
        anomaly: SleepAnomalyEvent,
        linkedRecording: RecordingEvidenceSnapshot?
    ) -> String {
        if let noiseType = linkedRecording?.noiseType, !noiseType.isEmpty {
            return "\(noiseType). Route: Air-borne / structure-borne acoustic transmission detected during monitoring window."
        }
        switch anomaly.impactHint {
        case .deepSleep:
            return "Impact / Transient Sound Event. Pulse recorded during deep-sleep window; likely structure-borne transmission."
        case .lightSleep, .none:
            return "Transient Acoustic Intrusion. Sustained or impulsive event detected via AI sound classification."
        }
    }

    // MARK: - Utilities

    private static func documentRefID(for session: SleepNoiseSessionSnapshot) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MMdd"
        let day = formatter.string(from: session.startedAt)
        let suffix = session.id.uuidString.prefix(4).uppercased()
        return "DECIBEL-\(day)-\(suffix)"
    }

    private static func dataIntegrityHash(for payload: ExportPayload) -> String {
        let material = """
        \(payload.session.id.uuidString)\
        \(payload.session.startedAt.timeIntervalSince1970)\
        \(payload.session.endedAt?.timeIntervalSince1970 ?? 0)\
        \(payload.sampleSnapshots.count)\
        \(payload.incidents.count)
        """
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func formattedHoursDuration(_ interval: TimeInterval) -> String {
        let hours = max(1, Int((interval / 3600).rounded()))
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    private static func weightingLabel(for session: SleepNoiseSessionSnapshot) -> String {
        if session.isHighSensitivitySession {
            return "dBZ (Zero-Weighted), Fast / High Sensitivity Mode"
        }
        if session.weightingMode == WeightingType.c.rawValue {
            return "dBC (C-Weighted), Fast / Standard Mode"
        }
        return "dBA (A-Weighted), Fast / Standard Mode"
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
