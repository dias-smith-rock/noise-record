import Foundation
import UIKit

enum SleepNEMRPDFExporter {
    private static let epaLDNLimit: Float = 55

    @MainActor
    static func export(
        payload: SleepForensicPDFExporter.ExportPayload,
        primaryLanguage: AppLanguage = .en
    ) -> URL? {
        let copy = SleepNEMRCopy(primaryLanguage: primaryLanguage)
        let metadata = SleepNEMRReportMetadata.build(
            session: payload.session,
            locationSummary: payload.locationSummary,
            sampleCount: payload.sampleSnapshots.count,
            copy: copy
        )
        let hourlyRows = SleepNEMRStatistics.hourlyResults(
            session: payload.session,
            samples: payload.sampleSnapshots
        )
        let peakRow = SleepNEMRStatistics.peakAnalysis(
            session: payload.session,
            anomalies: payload.incidents
        )
        let conclusion = SleepNEMRStatistics.buildConclusion(
            hourlyRows: hourlyRows,
            peakRow: peakRow,
            session: payload.session,
            copy: copy
        )

        let endedAt = payload.session.endedAt ?? payload.session.startedAt
        let langSuffix = copy.primaryLanguage.rawValue.replacingOccurrences(of: "-", with: "_")
        let fileName = "nighttime_noise_report_\(langSuffix)_\(SleepForensicPDFExporter.documentRefSuffix(for: payload.session)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: ForensicPDFLayout.Constants.pageSize)
        )

        let data = renderer.pdfData { context in
            ForensicPDFLayout.resetPageNumber()
            var y = ForensicPDFLayout.beginPage(context)

            y = drawCover(metadata: metadata, copy: copy, y: y)
            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 120)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionIntroduction, y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(y: y, paragraphs: [metadata.introductionParagraph])

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 140)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionStandards, y: y)
            y = drawStandardsTable(
                context: context,
                y: y,
                localLimit: hourlyRows.first?.localLimit ?? NoiseReferenceLimits.residentialNightDB,
                copy: copy
            )

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionInstrumentation, y: y)
            y = ForensicPDFLayout.drawKeyValueTable(rows: metadata.instrumentationRows, y: y, keyWidth: 150)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionLocations, y: y)
            y = ForensicPDFLayout.drawText(copy.subsectionPlacement, y: y, font: .boldSystemFont(ofSize: 10))
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: [copy.placementParagraph]
            )
            y = ForensicPDFLayout.drawText(copy.subsectionPointDescription, y: y, font: .boldSystemFont(ofSize: 10))
            y = ForensicPDFLayout.drawColumnTable(
                context: context,
                y: y,
                headers: [copy.colPoint, copy.colDescription, copy.colSource],
                rows: metadata.locationTableRows.map { [$0.0, $0.1, $0.2] },
                columnWidths: [36, 250, 130],
                fontSize: 7,
                rowHeight: 28
            )
            y = ForensicPDFLayout.drawText(copy.subsectionPeriodMethod, y: y, font: .boldSystemFont(ofSize: 10))
            y = ForensicPDFLayout.drawKeyValueTable(rows: metadata.methodologyRows, y: y, keyWidth: 150)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionResults, y: y)
            y = ForensicPDFLayout.drawText(copy.table1Title, y: y, font: .boldSystemFont(ofSize: 9))
            y = drawHourlyResultsTable(context: context, y: y, rows: hourlyRows, copy: copy)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 100)
            y = ForensicPDFLayout.drawText(copy.table2Title, y: y, font: .boldSystemFont(ofSize: 9))
            y = drawPeakAnalysisTable(context: context, y: y, row: peakRow, copy: copy)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 140)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionConclusion, y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: conclusion.overallConclusion + [conclusion.backgroundCorrectionNote] + conclusion.recommendations
            )

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 320)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionAppendices, y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: [
                    copy.appendixPhoto1,
                    copy.appendixPhoto2,
                    copy.appendixPhoto3,
                    copy.appendixA,
                    copy.appendixB,
                ]
            )
            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 240)
            y = ForensicPDFLayout.drawText(copy.trendTitle, y: y, font: .boldSystemFont(ofSize: 10))
            y += 8
            let peakMarkers = ForensicPDFLayout.makePeakMarkers(
                chartPoints: payload.chartPoints,
                incidents: payload.incidents,
                sessionPeakDB: payload.session.peakDB,
                sessionPeakTimestamp: payload.chartPoints.max(by: { $0.decibels < $1.decibels })?.timestamp
                    ?? payload.incidents.max(by: { $0.peakDB < $1.peakDB })?.timestamp
            )
            y = ForensicPDFLayout.drawTrendChart(
                y: y,
                points: payload.chartPoints,
                sessionStart: payload.session.startedAt,
                sessionEnd: endedAt,
                limitDB: epaLDNLimit,
                limitLabel: "Local Nighttime Limit (\(Int(epaLDNLimit)) dB)",
                peakMarkers: peakMarkers
            )
            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 80)
            y = ForensicPDFLayout.drawText(copy.anomalyLogTitle, y: y, font: .boldSystemFont(ofSize: 10))
            y += 4
            y = ForensicPDFLayout.drawIncidentLog(context: context, y: y, incidents: payload.incidents)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle(copy.sectionDisclaimer, y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: [
                    copy.disclaimerPeriod,
                    copy.disclaimerDevice,
                    copy.disclaimerReproduction(firm: copy.firmPlaceholder),
                ]
            )
            y += 8
            y = ForensicPDFLayout.drawText(copy.preparedBy, y: y, font: .systemFont(ofSize: 10))
            y = ForensicPDFLayout.drawText(copy.titleSignatory, y: y, font: .systemFont(ofSize: 10))
            y = ForensicPDFLayout.drawText(copy.reviewedBy, y: y, font: .systemFont(ofSize: 10))
            _ = ForensicPDFLayout.drawText(
                "\(copy.issuingAuthority) \(copy.firmPlaceholder)",
                y: y,
                font: .systemFont(ofSize: 10)
            )
        }

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func drawCover(
        metadata: SleepNEMRReportMetadata.ReportFields,
        copy: SleepNEMRCopy,
        y: CGFloat
    ) -> CGFloat {
        var cursor = ForensicPDFLayout.drawText(
            copy.coverTitlePrimary,
            y: y,
            font: .boldSystemFont(ofSize: 18)
        )
        if let secondary = copy.coverTitleSecondary {
            cursor = ForensicPDFLayout.drawText(
                secondary,
                y: cursor + 4,
                font: .boldSystemFont(ofSize: 14),
                color: ForensicPDFLayout.Colors.secondaryText
            )
        }
        cursor += 12
        return ForensicPDFLayout.drawKeyValueTable(
            rows: [
                (copy.fieldReportNo, metadata.reportNumber),
                (copy.fieldMonitoringDate, metadata.monitoringDateRange),
                (copy.fieldReportDate, metadata.reportDate),
                (copy.fieldClient, metadata.client),
                (copy.fieldSiteAddress, metadata.siteAddress),
                (copy.fieldPurpose, metadata.purpose),
                (copy.fieldFirm, metadata.monitoringFirm),
            ],
            y: cursor,
            keyWidth: 160
        )
    }

    private static func drawStandardsTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        localLimit: Float,
        copy: SleepNEMRCopy
    ) -> CGFloat {
        ForensicPDFLayout.drawColumnTable(
            context: context,
            y: y,
            headers: [copy.colStandard, copy.colTitleApplication],
            rows: [
                ["ANSI S1.4-1971 (R1976)", copy.standardANSI],
                ["EPA 550/9-74-004", copy.standardEPA],
                ["HUD 24 CFR Part 51", copy.standardHUD],
                [copy.standardLocalName, copy.localOrdinanceRow(limit: localLimit)],
            ],
            columnWidths: [120, 276],
            fontSize: 8,
            rowHeight: 24
        )
    }

    private static func drawHourlyResultsTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        rows: [SleepNEMRStatistics.HourlyResultRow],
        copy: SleepNEMRCopy
    ) -> CGFloat {
        let tableRows = rows.map { row in
            [
                "\(row.pointLabel)",
                row.timeRange,
                String(format: "%.1f", row.leq),
                String(format: "%.1f", row.lmax),
                String(format: "%.1f", row.l90),
                "≤ \(String(format: "%.0f", row.localLimit))",
                row.epaLDNSuggestion,
                copy.compliance(row.compliance),
            ]
        }
        return ForensicPDFLayout.drawColumnTable(
            context: context,
            y: y,
            headers: ["Point", "Time", "Leq", "Lmax", "L90", "Local", "EPA", "Result"],
            rows: tableRows,
            columnWidths: [28, 72, 34, 34, 34, 38, 34, 72],
            fontSize: 6.5,
            rowHeight: 12
        )
    }

    private static func drawPeakAnalysisTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        row: SleepNEMRStatistics.PeakAnalysisRow,
        copy: SleepNEMRCopy
    ) -> CGFloat {
        let timestampSummary: String
        if row.exceedTimestamps.isEmpty {
            timestampSummary = "—"
        } else {
            let listed = row.exceedTimestamps.prefix(3).map { ForensicPDFLayout.formattedTime($0) }.joined(separator: ", ")
            let suffix = row.exceedTimestamps.count > 3 ? "…" : ""
            timestampSummary = listed + suffix
        }

        return ForensicPDFLayout.drawColumnTable(
            context: context,
            y: y,
            headers: copy.peakTableHeaders,
            rows: [[
                row.pointLabel,
                "\(row.exceedCount)",
                timestampSummary,
                String(format: "%.1f dB(A)", row.highestLmax),
                copy.compliance(row.compliance),
            ]],
            columnWidths: [36, 70, 150, 70, 70],
            fontSize: 7,
            rowHeight: 14
        )
    }
}
