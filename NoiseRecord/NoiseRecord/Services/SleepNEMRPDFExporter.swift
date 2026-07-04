import Foundation
import UIKit

enum SleepNEMRPDFExporter {
    private static let epaLDNLimit: Float = 55

    @MainActor
    static func export(payload: SleepForensicPDFExporter.ExportPayload) -> URL? {
        let metadata = SleepNEMRReportMetadata.build(
            session: payload.session,
            locationSummary: payload.locationSummary,
            sampleCount: payload.sampleSnapshots.count
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
            session: payload.session
        )

        let endedAt = payload.session.endedAt ?? payload.session.startedAt
        let fileName = "nighttime_noise_report_\(SleepForensicPDFExporter.documentRefSuffix(for: payload.session)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: ForensicPDFLayout.Constants.pageSize)
        )

        let data = renderer.pdfData { context in
            ForensicPDFLayout.resetPageNumber()
            var y = ForensicPDFLayout.beginPage(context)

            y = drawCover(metadata: metadata, y: y)
            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 120)
            y = ForensicPDFLayout.drawSectionTitle("1. 引言 (Introduction)", y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(y: y, paragraphs: [metadata.introductionParagraph])

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 140)
            y = ForensicPDFLayout.drawSectionTitle("2. 监测依据与参考标准 (References & Standards)", y: y)
            y = drawStandardsTable(context: context, y: y, localLimit: hourlyRows.first?.localLimit ?? NoiseReferenceLimits.residentialNightDB)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle("3. 监测仪器与校准 (Instrumentation & Calibration)", y: y)
            y = ForensicPDFLayout.drawKeyValueTable(rows: metadata.instrumentationRows, y: y, keyWidth: 150)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle("4. 监测点位与方法 (Locations & Methodology)", y: y)
            y = ForensicPDFLayout.drawText("4.1 Placement Principle / 布点原则", y: y, font: .boldSystemFont(ofSize: 10))
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: [
                    "Monitoring was conducted at a single primary point (P1) using a calibrated consumer iOS device at receptor height. Multi-point professional survey grids (N1/N2/N3) are not applicable to this mobile session.",
                ]
            )
            y = ForensicPDFLayout.drawText("4.2 Monitoring Point Description / 监测点位描述", y: y, font: .boldSystemFont(ofSize: 10))
            y = ForensicPDFLayout.drawColumnTable(
                context: context,
                y: y,
                headers: ["Point / 点位", "Description / 位置描述", "Source / 声源性质"],
                rows: metadata.locationTableRows.map { [$0.0, $0.1, $0.2] },
                columnWidths: [36, 250, 130],
                fontSize: 7,
                rowHeight: 28
            )
            y = ForensicPDFLayout.drawText("4.3 Monitoring Period & Method / 监测时段与方法", y: y, font: .boldSystemFont(ofSize: 10))
            y = ForensicPDFLayout.drawKeyValueTable(rows: metadata.methodologyRows, y: y, keyWidth: 150)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle("5. 监测数据结果 (Measurement Results)", y: y)
            y = ForensicPDFLayout.drawText(
                "Table 1: Nighttime Noise Statistics (1-hour Leq) / 表1：夜间噪声监测数据统计表",
                y: y,
                font: .boldSystemFont(ofSize: 9)
            )
            y = drawHourlyResultsTable(context: context, y: y, rows: hourlyRows)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 100)
            y = ForensicPDFLayout.drawText(
                "Table 2: Impulsive/Peak Noise Analysis / 表2：突发噪音峰值分析",
                y: y,
                font: .boldSystemFont(ofSize: 9)
            )
            y = drawPeakAnalysisTable(context: context, y: y, row: peakRow)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 140)
            y = ForensicPDFLayout.drawSectionTitle("6. 结论与分析 (Conclusion & Analysis)", y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: conclusion.overallConclusion + [conclusion.backgroundCorrectionNote] + conclusion.recommendations
            )

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 320)
            y = ForensicPDFLayout.drawSectionTitle("7. 现场照片及附录 (Photographs & Appendices)", y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: [
                    "Photo 1 / 图1: [Field photo of sound level meter placement — not captured / 未采集现场照片]",
                    "Photo 2 / 图2: [Photo of noise source — not captured / 未采集声源照片]",
                    "Photo 3 / 图3: [Calibration certificate — not applicable to consumer iOS device / 不适用]",
                    "Appendix A / 附录A: [Field data sheets — available via in-app CSV export / 可通过 App 导出 CSV]",
                    "Appendix B / 附录B: Raw 1-second-level data available via in-app CSV export.",
                ]
            )
            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 240)
            y = ForensicPDFLayout.drawText("Overnight Level Trend / 整夜声级趋势", y: y, font: .boldSystemFont(ofSize: 10))
            y += 8
            y = ForensicPDFLayout.drawTrendChart(
                y: y,
                points: payload.chartPoints,
                sessionStart: payload.session.startedAt,
                sessionEnd: endedAt,
                limitDB: epaLDNLimit,
                limitLabel: "Local Nighttime Limit (\(Int(epaLDNLimit)) dB)"
            )
            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 80)
            y = ForensicPDFLayout.drawText("Anomaly Evidence Log / 异常事件证据", y: y, font: .boldSystemFont(ofSize: 10))
            y += 4
            y = ForensicPDFLayout.drawIncidentLog(context: context, y: y, incidents: payload.incidents)

            y = ForensicPDFLayout.ensureSpace(context: context, y: y, required: 160)
            y = ForensicPDFLayout.drawSectionTitle("8. 声明与局限性 (Disclaimer & Limitations)", y: y)
            y = ForensicPDFLayout.drawBodyParagraphs(
                y: y,
                paragraphs: disclaimerParagraphs(firm: metadata.monitoringFirm)
            )
            y += 8
            y = ForensicPDFLayout.drawText("Prepared by / 编制人: __________________", y: y, font: .systemFont(ofSize: 10))
            y = ForensicPDFLayout.drawText("Title / 职称/签名: Acoustic Engineer / Authorized Signatory", y: y, font: .systemFont(ofSize: 10))
            y = ForensicPDFLayout.drawText("Reviewed by / 审核人: __________________", y: y, font: .systemFont(ofSize: 10))
            _ = ForensicPDFLayout.drawText(
                "Issuing Authority / 签发机构: \(SleepNEMRReportMetadata.firmPlaceholder)",
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

    private static func drawCover(metadata: SleepNEMRReportMetadata.ReportFields, y: CGFloat) -> CGFloat {
        var cursor = ForensicPDFLayout.drawText(
            "夜间环境噪声监测报告",
            y: y,
            font: .boldSystemFont(ofSize: 18)
        )
        cursor = ForensicPDFLayout.drawText(
            "Nighttime Environmental Noise Monitoring Report",
            y: cursor + 4,
            font: .boldSystemFont(ofSize: 14),
            color: ForensicPDFLayout.Colors.secondaryText
        )
        cursor += 12
        return ForensicPDFLayout.drawKeyValueTable(
            rows: [
                ("报告编号 (Report No.)", metadata.reportNumber),
                ("监测日期 (Date of Monitoring)", metadata.monitoringDateRange),
                ("报告日期 (Date of Report)", metadata.reportDate),
                ("委托方 (Client)", metadata.client),
                ("监测地址 (Site Address)", metadata.siteAddress),
                ("监测目的 (Purpose)", metadata.purpose),
                ("监测单位 (Monitoring Firm)", metadata.monitoringFirm),
            ],
            y: cursor,
            keyWidth: 160
        )
    }

    private static func drawStandardsTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        localLimit: Float
    ) -> CGFloat {
        ForensicPDFLayout.drawColumnTable(
            context: context,
            y: y,
            headers: ["Standard / 标准编号", "Title & Application / 名称及适用内容"],
            rows: [
                ["ANSI S1.4-1971 (R1976)", "Sound level meter accuracy (Type 1 reference standard)"],
                ["EPA 550/9-74-004", "Community noise guidance — outdoor Ldn ≤ 55 dB(A) for residential areas"],
                ["HUD 24 CFR Part 51", "Acceptable outdoor DNL ≤ 65 dB; indoor ≤ 45 dB for HUD-assisted projects"],
                ["Local ordinance / 当地条例", "Nighttime residential Leq (1-hr) ≤ \(String(format: "%.0f", localLimit)) dB(A)"],
            ],
            columnWidths: [120, 276],
            fontSize: 8,
            rowHeight: 24
        )
    }

    private static func drawHourlyResultsTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        rows: [SleepNEMRStatistics.HourlyResultRow]
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
                row.compliance.rawValue,
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
        row: SleepNEMRStatistics.PeakAnalysisRow
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
            headers: ["Point", "Count > threshold", "Peak times", "Max Lmax", "Compliance"],
            rows: [[
                row.pointLabel,
                "\(row.exceedCount)",
                timestampSummary,
                String(format: "%.1f dB(A)", row.highestLmax),
                row.compliance.rawValue,
            ]],
            columnWidths: [36, 70, 150, 70, 70],
            fontSize: 7,
            rowHeight: 14
        )
    }

    private static func disclaimerParagraphs(firm: String) -> [String] {
        [
            """
            This report reflects environmental noise conditions only for the monitored period and point(s). It may not represent other time periods or weather conditions.

            本报告仅对监测期间、监测点位当时的环境噪音状况负责，不能完全代表该区域在其他时间段或不同气象条件下的噪音水平。
            """,
            """
            Data were collected using consumer iOS hardware and Decibel Meter Pro. This is not an ANSI Type 1 certified measurement and should be interpreted as evidentiary reference data.

            本报告数据基于移动设备测量方法，具有参考追溯性，但不等同于专业认证声级计测量。
            """,
            """
            This report may not be partially reproduced without written approval from \(SleepNEMRReportMetadata.firmPlaceholder).

            本报告未经 \(SleepNEMRReportMetadata.firmPlaceholder) 书面批准，不得部分复制（全文复制除外）。
            """,
        ]
    }
}
