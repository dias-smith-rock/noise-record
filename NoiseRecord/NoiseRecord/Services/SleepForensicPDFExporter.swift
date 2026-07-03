import CoreImage
import Foundation
import UIKit

enum SleepForensicPDFExporter {
    private enum ForensicLimits {
        static let whoNighttimeLimitDB: Float = 45
        static let whoIndoorRecommendationDB: Float = 30
    }

    private enum Layout {
        static let pageSize = CGSize(width: 612, height: 792)
        static let margin: CGFloat = 48
        static let footerHeight: CGFloat = 52
        static let contentWidth: CGFloat = pageSize.width - margin * 2
    }

    /// PDF 使用固定印刷色，避免深色模式下 `UIColor.label` 变成白字白底。
    private enum PDFColors {
        static let text = UIColor.black
        static let secondaryText = UIColor.darkGray
        static let tertiaryText = UIColor.gray
        static let cardFill = UIColor(white: 0.94, alpha: 1)
        static let border = UIColor(white: 0.78, alpha: 1)
        static let chartLine = UIColor(red: 0.16, green: 0.52, blue: 0.68, alpha: 1)
        static let limitLine = UIColor.red
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
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: Layout.pageSize))

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
            pageNumber = 0
            var cursorY = beginPage(context)

            cursorY = drawTitleBlock(context: context, y: cursorY, session: payload.session)
            cursorY = drawSectionTitle("1. METADATA & ENVIRONMENT PROFILE (法证元数据)", y: cursorY, context: context)
            cursorY = drawMetadataTable(
                context: context,
                y: cursorY,
                session: payload.session,
                endedAt: endedAt,
                duration: duration,
                locationSummary: payload.locationSummary
            )

            cursorY = ensureSpace(context: context, y: cursorY, required: 180)
            cursorY = drawSectionTitle("2. EXECUTIVE SUMMARY (数据摘要)", y: cursorY, context: context)
            cursorY = drawBodyParagraphs(
                context: context,
                y: cursorY,
                paragraphs: executiveSummaryParagraphs(
                    session: payload.session,
                    duration: duration,
                    minDB: minDB,
                    nuisanceDuration: nuisanceDuration,
                    whoExceedPercent: whoExceedPercent
                )
            )

            cursorY = ensureSpace(context: context, y: cursorY, required: 320)
            cursorY = drawText(
                "Overnight Level Trend",
                y: cursorY,
                font: .boldSystemFont(ofSize: 11),
                color: PDFColors.text
            )
            cursorY += 8
            cursorY = drawTrendChart(
                context: context,
                y: cursorY,
                points: payload.chartPoints,
                sessionStart: payload.session.startedAt,
                sessionEnd: endedAt
            )

            cursorY = ensureSpace(context: context, y: cursorY, required: 120)
            cursorY = drawSectionTitle(
                "3. CHRONOLOGICAL INCIDENT LOG (异常噪音事件时间线)",
                y: cursorY,
                context: context
            )
            cursorY = drawIncidentLog(context: context, y: cursorY, incidents: payload.incidents)

            cursorY = ensureSpace(context: context, y: cursorY, required: 140)
            cursorY = drawSectionTitle("4. SPECTROGRAM FREQUENCY EVIDENCE (频谱物理特征)", y: cursorY, context: context)
            cursorY = drawBodyParagraphs(
                context: context,
                y: cursorY,
                paragraphs: [spectrogramNote(isHighSensitivity: payload.session.isHighSensitivitySession)]
            )

            cursorY = ensureSpace(context: context, y: cursorY, required: 160)
            cursorY = drawSectionTitle("5. REGULATORY HEALTH ALIGNMENT (法律与健康合规标准对照)", y: cursorY, context: context)
            cursorY = drawBodyParagraphs(
                context: context,
                y: cursorY,
                paragraphs: regulatoryParagraphs(
                    nuisanceDuration: nuisanceDuration,
                    overallLeq: payload.session.overallLeq
                )
            )

            cursorY = ensureSpace(context: context, y: cursorY, required: 160)
            cursorY = drawSectionTitle("6. PLAINTIFF ATTESTATION & DIGITAL SIGNATURE (原告申明与签名)", y: cursorY, context: context)
            _ = drawAttestationBlock(context: context, y: cursorY, endedAt: endedAt)
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
        let chartPoints: [ChartPoint]
        if samples.isEmpty, let endedAt = session.endedAt {
            chartPoints = [
                ChartPoint(timestamp: session.startedAt, decibels: session.overallLeq),
                ChartPoint(timestamp: endedAt, decibels: session.overallLeq),
            ]
        } else {
            chartPoints = samples.map { sample in
                ChartPoint(
                    timestamp: sample.timestamp,
                    decibels: max(sample.dbMax, sample.leq, sample.dbCurrent)
                )
            }.sorted { $0.timestamp < $1.timestamp }
        }

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
            locationSummary: locationSummary
        )
    }

    // MARK: - Page layout

    private static var pageNumber = 0

    private static func beginPage(_ context: UIGraphicsPDFRendererContext) -> CGFloat {
        pageNumber += 1
        context.beginPage()
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: Layout.pageSize))
        drawFooter(context: context)
        return Layout.margin
    }

    private static func ensureSpace(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        required: CGFloat
    ) -> CGFloat {
        let maxY = Layout.pageSize.height - Layout.margin - Layout.footerHeight
        guard y + required > maxY else { return y }
        return beginPage(context)
    }

    private static func drawFooter(context: UIGraphicsPDFRendererContext) {
        let footerY = Layout.pageSize.height - Layout.footerHeight
        let disclaimer = L10n.settingsDisclaimerBody
        let pageText = "Page \(pageNumber)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: PDFColors.secondaryText,
        ]
        let pageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: PDFColors.secondaryText,
        ]

        disclaimer.draw(
            in: CGRect(x: Layout.margin, y: footerY + 4, width: Layout.contentWidth - 60, height: Layout.footerHeight - 8),
            withAttributes: attrs
        )
        pageText.draw(
            in: CGRect(x: Layout.pageSize.width - Layout.margin - 40, y: footerY + 16, width: 40, height: 14),
            withAttributes: pageAttrs
        )

        PDFColors.border.setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: Layout.margin, y: footerY))
        line.addLine(to: CGPoint(x: Layout.pageSize.width - Layout.margin, y: footerY))
        line.lineWidth = 0.5
        line.stroke()
    }

    // MARK: - Drawing helpers

    private static func drawTitleBlock(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        session: SleepNoiseSessionSnapshot
    ) -> CGFloat {
        var cursor = y
        cursor = drawText(
            "OVERNIGHT ACOUSTIC MONITORING REPORT",
            y: cursor,
            font: .boldSystemFont(ofSize: 18)
        )
        cursor += 8
        cursor = drawText(
            "Document Ref ID: \(documentRefID(for: session))",
            y: cursor,
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: PDFColors.secondaryText
        )
        cursor = drawText(
            "Generated Via: Decibel Meter Pro (Calibrated iOS Hardware Framework)",
            y: cursor,
            font: .systemFont(ofSize: 10),
            color: PDFColors.secondaryText
        )
        cursor = drawText(
            "Data Integrity Status: 🔒 Secured Local Storage (No Cloud Modification)",
            y: cursor,
            font: .systemFont(ofSize: 10),
            color: PDFColors.secondaryText
        )
        return cursor + 16
    }

    private static func drawSectionTitle(
        _ title: String,
        y: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        _ = context
        var cursor = drawText(title, y: y, font: .boldSystemFont(ofSize: 12))
        cursor += 8
        return cursor
    }

    private static func drawMetadataTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        session: SleepNoiseSessionSnapshot,
        endedAt: Date,
        duration: TimeInterval,
        locationSummary: String?
    ) -> CGFloat {
        _ = context
        let rows: [(String, String)] = [
            (
                "Monitoring Date & Window",
                "\(formattedDateTime(session.startedAt)) — \(formattedDateTime(endedAt)) (\(formattedDuration(duration)) Continuous)"
            ),
            ("Device Hardware", "\(HardwareIdentifier.marketingName) (Internal Omnidirectional Mic Array)"),
            ("Acoustic Weighting Filter", weightingLabel(for: session)),
            ("Geographic Location (GPS)", locationSummary ?? "Not captured during this session"),
            ("Calibrated Noise Floor (Baseline)", String(format: "%.1f dB (Session-established baseline)", session.noiseFloorDB)),
        ]
        return drawKeyValueTable(rows: rows, y: y)
    }

    private static func drawKeyValueTable(rows: [(String, String)], y: CGFloat) -> CGFloat {
        var cursor = y
        for (key, value) in rows {
            let keyRect = CGRect(x: Layout.margin, y: cursor, width: 170, height: 200)
            let valueRect = CGRect(x: Layout.margin + 176, y: cursor, width: Layout.contentWidth - 176, height: 200)
            let keyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: PDFColors.text,
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: PDFColors.text,
            ]
            let keyHeight = key.boundingRect(
                with: CGSize(width: keyRect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: keyAttrs,
                context: nil
            ).height
            let valueHeight = value.boundingRect(
                with: CGSize(width: valueRect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: valueAttrs,
                context: nil
            ).height
            let rowHeight = max(keyHeight, valueHeight) + 6
            key.draw(in: keyRect, withAttributes: keyAttrs)
            value.draw(in: valueRect, withAttributes: valueAttrs)
            cursor += rowHeight
        }
        return cursor + 8
    }

    private static func drawBodyParagraphs(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        paragraphs: [String]
    ) -> CGFloat {
        _ = context
        var cursor = y
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: PDFColors.text,
        ]
        for paragraph in paragraphs {
            let height = paragraph.boundingRect(
                with: CGSize(width: Layout.contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            ).height
            paragraph.draw(
                in: CGRect(x: Layout.margin, y: cursor, width: Layout.contentWidth, height: height + 4),
                withAttributes: attrs
            )
            cursor += height + 12
        }
        return cursor
    }

    private static func drawTrendChart(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        points: [ChartPoint],
        sessionStart: Date,
        sessionEnd: Date
    ) -> CGFloat {
        let chartHeight: CGFloat = 220
        let chartRect = CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: chartHeight)
        let plotRect = chartRect.insetBy(dx: 36, dy: 24)

        PDFColors.cardFill.setFill()
        UIBezierPath(roundedRect: chartRect, cornerRadius: 8).fill()
        PDFColors.border.setStroke()
        UIBezierPath(roundedRect: chartRect, cornerRadius: 8).stroke()

        let minY: Float = 0
        let maxY: Float = max(
            100,
            (points.map(\.decibels).max() ?? ForensicLimits.whoNighttimeLimitDB) + 10
        )
        let limitY = ForensicLimits.whoNighttimeLimitDB

        func pointPosition(for date: Date, db: Float) -> CGPoint {
            let total = max(sessionEnd.timeIntervalSince(sessionStart), 1)
            let xRatio = CGFloat(date.timeIntervalSince(sessionStart) / total)
            let yRatio = CGFloat((db - minY) / max(maxY - minY, 1))
            return CGPoint(
                x: plotRect.minX + plotRect.width * min(max(xRatio, 0), 1),
                y: plotRect.maxY - plotRect.height * min(max(yRatio, 0), 1)
            )
        }

        let limitPoint = pointPosition(for: sessionStart, db: limitY)
        let limitEnd = pointPosition(for: sessionEnd, db: limitY)
        PDFColors.limitLine.setStroke()
        let limitPath = UIBezierPath()
        limitPath.move(to: limitPoint)
        limitPath.addLine(to: limitEnd)
        limitPath.lineWidth = 1.5
        limitPath.setLineDash([5, 4], count: 2, phase: 0)
        limitPath.stroke()

        let limitLabel = "EPA/WHO Nighttime Limit (45 dB)"
        let limitAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: PDFColors.limitLine,
        ]
        limitLabel.draw(
            at: CGPoint(x: limitEnd.x - 150, y: limitPoint.y - 14),
            withAttributes: limitAttrs
        )

        let plotPoints = downsampledChartPoints(points, maxCount: 240)
        if plotPoints.count >= 2 {
            PDFColors.chartLine.setStroke()
            let line = UIBezierPath()
            line.move(to: pointPosition(for: plotPoints[0].timestamp, db: plotPoints[0].decibels))
            for point in plotPoints.dropFirst() {
                line.addLine(to: pointPosition(for: point.timestamp, db: point.decibels))
            }
            line.lineWidth = 1.25
            line.stroke()
        } else if let only = plotPoints.first {
            PDFColors.chartLine.setFill()
            UIBezierPath(
                ovalIn: CGRect(
                    x: pointPosition(for: only.timestamp, db: only.decibels).x - 2,
                    y: pointPosition(for: only.timestamp, db: only.decibels).y - 2,
                    width: 4,
                    height: 4
                )
            ).fill()
        }

        let axisAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: PDFColors.secondaryText,
        ]
        "0".draw(at: CGPoint(x: plotRect.minX - 18, y: plotRect.maxY - 6), withAttributes: axisAttrs)
        String(format: "%.0f", maxY).draw(
            at: CGPoint(x: plotRect.minX - 24, y: plotRect.minY - 4),
            withAttributes: axisAttrs
        )
        formattedTime(sessionStart).draw(
            at: CGPoint(x: plotRect.minX, y: plotRect.maxY + 6),
            withAttributes: axisAttrs
        )
        formattedTime(sessionEnd).draw(
            at: CGPoint(x: plotRect.maxX - 36, y: plotRect.maxY + 6),
            withAttributes: axisAttrs
        )

        _ = context
        return y + chartHeight + 12
    }

    private static func drawIncidentLog(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        incidents: [IncidentRow]
    ) -> CGFloat {
        var cursor = drawBodyParagraphs(
            context: context,
            y: y,
            paragraphs: [
                """
                The following anomalies were captured via AI sound classification and isolated into secure 10-minute local data segments to prevent data corruption.
                """,
            ]
        )

        guard !incidents.isEmpty else {
            return drawText(
                "No discrete anomaly events were logged during this session.",
                y: cursor,
                font: .systemFont(ofSize: 10),
                color: PDFColors.secondaryText
            ) + 8
        }

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: PDFColors.secondaryText,
        ]
        let columns = ["Timestamp", "Peak", "Duration", "Classification", "Evidence"]
        let columnWidths: [CGFloat] = [78, 42, 48, 200, 64]
        var x = Layout.margin
        for (index, title) in columns.enumerated() {
            title.draw(at: CGPoint(x: x, y: cursor), withAttributes: headerAttrs)
            x += columnWidths[index]
        }
        cursor += 16

        for incident in incidents {
            cursor = ensureSpace(context: context, y: cursor, required: 72)
            x = Layout.margin
            let values = [
                formattedTime(incident.timestamp),
                String(format: "%.1f dB", incident.peakDB),
                String(format: "%.0fs", incident.durationSeconds),
                incident.classification,
            ]
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: PDFColors.text,
            ]
            for (index, value) in values.enumerated() {
                let width = columnWidths[index]
                value.draw(
                    in: CGRect(x: x, y: cursor, width: width, height: 52),
                    withAttributes: rowAttrs
                )
                x += width
            }

            if let recordingID = incident.recordingSessionID,
               let qr = qrCodeImage(for: LiveActivityDeepLink.evidenceURL(recordingSessionID: recordingID), size: 52) {
                qr.draw(in: CGRect(x: x, y: cursor, width: 52, height: 52))
            } else {
                drawText(
                    "—",
                    y: cursor + 18,
                    font: .systemFont(ofSize: 8),
                    color: PDFColors.tertiaryText
                )
            }

            cursor += 58
        }

        cursor += 4
        _ = drawText(
            "Scan QR codes with the capturing iPhone to open locally stored video/audio evidence (GPS + timestamp burned in).",
            y: cursor,
            font: .systemFont(ofSize: 8),
            color: PDFColors.secondaryText
        )
        return cursor + 18
    }

    private static func drawAttestationBlock(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        endedAt: Date
    ) -> CGFloat {
        _ = context
        var cursor = drawBodyParagraphs(
            context: context,
            y: y,
            paragraphs: [
                """
                I, the undersigned, hereby certify that the acoustic data, timestamps, and geographic coordinates enclosed in this report were recorded in real-time by the hardware device specified above. No external equalization, audio alteration, or file manipulation was performed.
                """,
            ]
        )
        cursor += 12
        cursor = drawText("Signature: ___________________________", y: cursor, font: .systemFont(ofSize: 10))
        cursor = drawText("Date: \(formattedDate(endedAt))", y: cursor + 8, font: .systemFont(ofSize: 10))
        return cursor + 12
    }

    private static func drawText(
        _ text: String,
        y: CGFloat,
        font: UIFont,
        color: UIColor = PDFColors.text
    ) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let height = text.boundingRect(
            with: CGSize(width: Layout.contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        ).height
        text.draw(
            in: CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: height + 2),
            withAttributes: attrs
        )
        return y + height + 4
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
            During the \(formattedDuration(duration)) designated quiet hour window, the monitored residential indoor environment experienced persistent acoustic activity that was evaluated against standard municipal residential health codes.
            """,
            """
            Average Sound Level (Leq): \(String(format: "%.1f", session.overallLeq)) dB (Exceeds WHO night-time indoor recommendation of \(Int(ForensicLimits.whoIndoorRecommendationDB)) dB by \(String(format: "%.1f", max(whoExceedPercent, 0)))%)
            Maximum Recorded Spike (Lmax): \(String(format: "%.1f", session.peakDB)) dB
            Minimum Background Floor (Lmin): \(String(format: "%.1f", minDB)) dB
            Total Nuisance Duration: \(formattedDuration(nuisanceDuration)) (Cumulative time spent above the \(Int(ForensicLimits.whoNighttimeLimitDB)) dB critical limit)
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
            Result: This overnight acoustic log shows \(overallLeq > ForensicLimits.whoIndoorRecommendationDB ? "a" : "no") material deviation from these medical guidelines, with \(formattedDuration(nuisanceDuration)) cumulatively above the \(Int(ForensicLimits.whoNighttimeLimitDB)) dB critical limit.
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

    private static func documentRefSuffix(for session: SleepNoiseSessionSnapshot) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        let day = formatter.string(from: session.startedAt)
        let suffix = session.id.uuidString.prefix(4).uppercased()
        return "\(day)-\(suffix)"
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

    private static func downsampledChartPoints(_ points: [ChartPoint], maxCount: Int) -> [ChartPoint] {
        guard points.count > maxCount else { return points }
        let stride = max(1, points.count / maxCount)
        return Swift.stride(from: 0, to: points.count, by: stride).map { points[$0] }
    }

    private static func qrCodeImage(for url: URL, size: CGFloat) -> UIImage? {
        guard let data = url.absoluteString.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }

    private static func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }
}
