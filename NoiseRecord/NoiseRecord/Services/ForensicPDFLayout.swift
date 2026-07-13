import CoreImage
import Foundation
import UIKit

enum ForensicPDFLayout {
    enum FooterStyle {
        case standardDisclaimer
        case overnightReport(documentRef: String)
    }

    enum Constants {
        static let pageSize = CGSize(width: 612, height: 792)
        static let margin: CGFloat = 48
        static let footerHeight: CGFloat = 52
        static let contentWidth: CGFloat = pageSize.width - margin * 2
    }

    enum Colors {
        static let text = UIColor.black
        static let secondaryText = UIColor.darkGray
        static let tertiaryText = UIColor.gray
        static let cardFill = UIColor(white: 0.94, alpha: 1)
        static let border = UIColor.black
        static let chartLine = UIColor(red: 0.16, green: 0.52, blue: 0.68, alpha: 1)
        static let limitLine = UIColor.red
    }

    static let footerDisclaimer =
        "Decibel Meter uses your iPhone microphone and is not a certified sound level meter. Readings are estimates for personal reference and evidence documentation only."

    private static var pageNumber = 0
    private static var footerStyle: FooterStyle = .standardDisclaimer

    static func resetPageNumber(footerStyle: FooterStyle = .standardDisclaimer) {
        pageNumber = 0
        self.footerStyle = footerStyle
    }

    static func beginPage(_ context: UIGraphicsPDFRendererContext) -> CGFloat {
        pageNumber += 1
        context.beginPage()
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: Constants.pageSize))
        drawFooter(context: context)
        return Constants.margin
    }

    static func ensureSpace(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        required: CGFloat
    ) -> CGFloat {
        let maxY = Constants.pageSize.height - Constants.margin - Constants.footerHeight
        guard y + required > maxY else { return y }
        return beginPage(context)
    }

    static func drawFooter(context: UIGraphicsPDFRendererContext) {
        let footerY = Constants.pageSize.height - Constants.footerHeight

        Colors.border.setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: Constants.margin, y: footerY))
        line.addLine(to: CGPoint(x: Constants.pageSize.width - Constants.margin, y: footerY))
        line.lineWidth = 0.5
        line.stroke()

        switch footerStyle {
        case .standardDisclaimer:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7),
                .foregroundColor: Colors.secondaryText,
            ]
            let pageAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: Colors.secondaryText,
            ]

            footerDisclaimer.draw(
                in: CGRect(
                    x: Constants.margin,
                    y: footerY + 4,
                    width: Constants.contentWidth - 60,
                    height: Constants.footerHeight - 8
                ),
                withAttributes: attrs
            )
            "Page \(pageNumber)".draw(
                in: CGRect(x: Constants.pageSize.width - Constants.margin - 40, y: footerY + 16, width: 40, height: 14),
                withAttributes: pageAttrs
            )

        case let .overnightReport(documentRef):
            let footerText = "OVERNIGHT ACOUSTIC MONITORING REPORT - \(documentRef)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: Colors.text,
            ]
            footerText.draw(
                in: CGRect(
                    x: Constants.margin,
                    y: footerY + 18,
                    width: Constants.contentWidth,
                    height: Constants.footerHeight - 8
                ),
                withAttributes: attrs
            )
        }
    }

    static func drawSectionTitle(_ title: String, y: CGFloat) -> CGFloat {
        var cursor = drawText(title, y: y, font: .boldSystemFont(ofSize: 12))
        cursor += 8
        return cursor
    }

    static func drawKeyValueTable(rows: [(String, String)], y: CGFloat, keyWidth: CGFloat = 170) -> CGFloat {
        var cursor = y
        for (key, value) in rows {
            let keyRect = CGRect(x: Constants.margin, y: cursor, width: keyWidth, height: 200)
            let valueRect = CGRect(
                x: Constants.margin + keyWidth + 6,
                y: cursor,
                width: Constants.contentWidth - keyWidth - 6,
                height: 200
            )
            let keyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: Colors.text,
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: Colors.text,
            ]
            let keyHeight = measuredHeight(text: key, width: keyRect.width, attributes: keyAttrs)
            let valueHeight = measuredHeight(text: value, width: valueRect.width, attributes: valueAttrs)
            let rowHeight = max(keyHeight, valueHeight) + 6
            key.draw(in: keyRect, withAttributes: keyAttrs)
            value.draw(in: valueRect, withAttributes: valueAttrs)
            cursor += rowHeight
        }
        return cursor + 8
    }

    static func drawBodyParagraphs(y: CGFloat, paragraphs: [String], fontSize: CGFloat = 10) -> CGFloat {
        var cursor = y
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: Colors.text,
        ]
        for paragraph in paragraphs {
            let height = measuredHeight(text: paragraph, width: Constants.contentWidth, attributes: attrs)
            paragraph.draw(
                in: CGRect(x: Constants.margin, y: cursor, width: Constants.contentWidth, height: height + 4),
                withAttributes: attrs
            )
            cursor += height + 12
        }
        return cursor
    }

    static func drawColumnTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        headers: [String],
        rows: [[String]],
        columnWidths: [CGFloat],
        fontSize: CGFloat = 7,
        rowHeight: CGFloat = 14
    ) -> CGFloat {
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: Colors.secondaryText,
        ]
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: Colors.text,
        ]

        var cursor = y
        var x = Constants.margin
        for (index, title) in headers.enumerated() {
            title.draw(
                in: CGRect(x: x, y: cursor, width: columnWidths[index], height: rowHeight + 4),
                withAttributes: headerAttrs
            )
            x += columnWidths[index]
        }
        cursor += rowHeight + 6

        for row in rows {
            cursor = ensureSpace(context: context, y: cursor, required: rowHeight + 4)
            x = Constants.margin
            for (index, value) in row.enumerated() {
                value.draw(
                    in: CGRect(x: x, y: cursor, width: columnWidths[index], height: rowHeight + 8),
                    withAttributes: cellAttrs
                )
                x += columnWidths[index]
            }
            cursor += rowHeight + 2
        }

        return cursor + 8
    }

    static func drawText(
        _ text: String,
        y: CGFloat,
        font: UIFont,
        color: UIColor = Colors.text
    ) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let height = measuredHeight(text: text, width: Constants.contentWidth, attributes: attrs)
        text.draw(
            in: CGRect(x: Constants.margin, y: y, width: Constants.contentWidth, height: height + 2),
            withAttributes: attrs
        )
        return y + height + 4
    }

    static func drawCenteredText(
        _ text: String,
        y: CGFloat,
        font: UIFont,
        color: UIColor = Colors.text
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let height = measuredHeight(text: text, width: Constants.contentWidth, attributes: attrs)
        text.draw(
            in: CGRect(x: Constants.margin, y: y, width: Constants.contentWidth, height: height + 2),
            withAttributes: attrs
        )
        return y + height + 4
    }

    static func drawBulletedList(y: CGFloat, items: [String], fontSize: CGFloat = 9) -> CGFloat {
        var cursor = y
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: Colors.text,
        ]
        for item in items {
            let bulletText = "• \(item)"
            let height = measuredHeight(text: bulletText, width: Constants.contentWidth, attributes: attrs)
            bulletText.draw(
                in: CGRect(x: Constants.margin, y: cursor, width: Constants.contentWidth, height: height + 2),
                withAttributes: attrs
            )
            cursor += height + 6
        }
        return cursor + 4
    }

    static func drawBorderedTable(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        headers: [String],
        rows: [[String]],
        columnWidths: [CGFloat],
        fontSize: CGFloat = 8,
        padding: CGFloat = 4
    ) -> CGFloat {
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: Colors.text,
        ]
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: Colors.text,
        ]

        func rowHeight(for values: [String], attributes: [NSAttributedString.Key: Any]) -> CGFloat {
            var maxHeight: CGFloat = 0
            for (index, value) in values.enumerated() {
                let width = max(columnWidths[index] - padding * 2, 1)
                let height = measuredHeight(text: value, width: width, attributes: attributes)
                maxHeight = max(maxHeight, height)
            }
            return max(maxHeight + padding * 2, 16)
        }

        func drawRow(at rowY: CGFloat, values: [String], attributes: [NSAttributedString.Key: Any], height: CGFloat) {
            var x = Constants.margin
            for (index, value) in values.enumerated() {
                let cellRect = CGRect(x: x, y: rowY, width: columnWidths[index], height: height)
                strokeRect(cellRect)
                value.draw(
                    in: cellRect.insetBy(dx: padding, dy: padding),
                    withAttributes: attributes
                )
                x += columnWidths[index]
            }
        }

        var cursor = y
        let headerHeight = rowHeight(for: headers, attributes: headerAttrs)
        cursor = ensureSpace(context: context, y: cursor, required: headerHeight)
        drawRow(at: cursor, values: headers, attributes: headerAttrs, height: headerHeight)
        cursor += headerHeight

        for row in rows {
            let height = rowHeight(for: row, attributes: cellAttrs)
            cursor = ensureSpace(context: context, y: cursor, required: height)
            drawRow(at: cursor, values: row, attributes: cellAttrs, height: height)
            cursor += height
        }

        return cursor + 8
    }

    static func drawOvernightIncidentLog(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        incidents: [SleepForensicPDFExporter.IncidentRow]
    ) -> CGFloat {
        var cursor = drawBodyParagraphs(
            y: y,
            paragraphs: [
                """
                The following incidents were captured and processed via AI sound classification during the monitoring window.
                """,
            ],
            fontSize: 9
        )

        guard !incidents.isEmpty else {
            return drawText(
                "No discrete acoustic events were logged during this session.",
                y: cursor,
                font: .systemFont(ofSize: 9),
                color: Colors.secondaryText
            ) + 8
        }

        let headers = ["Timestamp (Local)", "Peak Value (dB)", "Duration", "AI Classification & Acoustic Profile"]
        let columnWidths: [CGFloat] = [84, 68, 44, Constants.contentWidth - 196]
        let rows = incidents.map { incident in
            [
                formattedTime(incident.timestamp),
                String(format: "%.1f dB", incident.peakDB),
                String(format: "%.0fs", incident.durationSeconds),
                incident.classification,
            ]
        }

        return drawBorderedTable(
            context: context,
            y: cursor,
            headers: headers,
            rows: rows,
            columnWidths: columnWidths,
            fontSize: 7.5
        )
    }

    private static func strokeRect(_ rect: CGRect) {
        Colors.border.setStroke()
        let path = UIBezierPath(rect: rect)
        path.lineWidth = 0.5
        path.stroke()
    }

    static func drawTrendChart(
        y: CGFloat,
        points: [SleepForensicPDFExporter.ChartPoint],
        sessionStart: Date,
        sessionEnd: Date,
        limitDB: Float = 45,
        limitLabel: String = "EPA/WHO Nighttime Limit (45 dB)"
    ) -> CGFloat {
        let chartHeight: CGFloat = 220
        let chartRect = CGRect(x: Constants.margin, y: y, width: Constants.contentWidth, height: chartHeight)
        let plotRect = chartRect.insetBy(dx: 36, dy: 24)

        Colors.cardFill.setFill()
        UIBezierPath(roundedRect: chartRect, cornerRadius: 8).fill()
        Colors.border.setStroke()
        UIBezierPath(roundedRect: chartRect, cornerRadius: 8).stroke()

        let minY: Float = 0
        let maxY: Float = max(100, (points.map(\.decibels).max() ?? limitDB) + 10)

        func pointPosition(for date: Date, db: Float) -> CGPoint {
            let total = max(sessionEnd.timeIntervalSince(sessionStart), 1)
            let xRatio = CGFloat(date.timeIntervalSince(sessionStart) / total)
            let yRatio = CGFloat((db - minY) / max(maxY - minY, 1))
            return CGPoint(
                x: plotRect.minX + plotRect.width * min(max(xRatio, 0), 1),
                y: plotRect.maxY - plotRect.height * min(max(yRatio, 0), 1)
            )
        }

        let limitPoint = pointPosition(for: sessionStart, db: limitDB)
        let limitEnd = pointPosition(for: sessionEnd, db: limitDB)
        Colors.limitLine.setStroke()
        let limitPath = UIBezierPath()
        limitPath.move(to: limitPoint)
        limitPath.addLine(to: limitEnd)
        limitPath.lineWidth = 1.5
        limitPath.setLineDash([5, 4], count: 2, phase: 0)
        limitPath.stroke()

        let limitAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: Colors.limitLine,
        ]
        limitLabel.draw(
            at: CGPoint(x: limitEnd.x - 150, y: limitPoint.y - 14),
            withAttributes: limitAttrs
        )

        let plotPoints = downsampledChartPoints(points, maxCount: 240)
        if plotPoints.count >= 2 {
            Colors.chartLine.setStroke()
            let line = UIBezierPath()
            line.move(to: pointPosition(for: plotPoints[0].timestamp, db: plotPoints[0].decibels))
            for point in plotPoints.dropFirst() {
                line.addLine(to: pointPosition(for: point.timestamp, db: point.decibels))
            }
            line.lineWidth = 1.25
            line.stroke()
        } else if let only = plotPoints.first {
            Colors.chartLine.setFill()
            let center = pointPosition(for: only.timestamp, db: only.decibels)
            UIBezierPath(ovalIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)).fill()
        }

        let axisAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: Colors.secondaryText,
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

        return y + chartHeight + 12
    }

    static func drawIncidentLog(
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        incidents: [SleepForensicPDFExporter.IncidentRow]
    ) -> CGFloat {
        var cursor = drawBodyParagraphs(
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
                color: Colors.secondaryText
            ) + 8
        }

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: Colors.secondaryText,
        ]
        let columns = ["Timestamp", "Peak", "Duration", "Classification", "Evidence"]
        let columnWidths: [CGFloat] = [78, 42, 48, 200, 64]
        var x = Constants.margin
        for (index, title) in columns.enumerated() {
            title.draw(at: CGPoint(x: x, y: cursor), withAttributes: headerAttrs)
            x += columnWidths[index]
        }
        cursor += 16

        for incident in incidents {
            cursor = ensureSpace(context: context, y: cursor, required: 72)
            x = Constants.margin
            let values = [
                formattedTime(incident.timestamp),
                String(format: "%.1f dB", incident.peakDB),
                String(format: "%.0fs", incident.durationSeconds),
                incident.classification,
            ]
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: Colors.text,
            ]
            for (index, value) in values.enumerated() {
                value.draw(
                    in: CGRect(x: x, y: cursor, width: columnWidths[index], height: 52),
                    withAttributes: rowAttrs
                )
                x += columnWidths[index]
            }

            if let recordingID = incident.recordingSessionID,
               let qr = qrCodeImage(for: LiveActivityDeepLink.evidenceURL(recordingSessionID: recordingID), size: 52) {
                qr.draw(in: CGRect(x: x, y: cursor, width: 52, height: 52))
            } else {
                _ = drawText("—", y: cursor + 18, font: .systemFont(ofSize: 8), color: Colors.tertiaryText)
            }

            cursor += 58
        }

        cursor += 4
        cursor = drawText(
            "Scan QR codes with the capturing iPhone to open locally stored video/audio evidence (GPS + timestamp burned in).",
            y: cursor,
            font: .systemFont(ofSize: 8),
            color: Colors.secondaryText
        )
        return cursor + 4
    }

    static func qrCodeImage(for url: URL, size: CGFloat) -> UIImage? {
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

    static func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func formattedDateRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            return "\(formattedDate(start)), \(formattedTime(start)) – \(formattedTime(end))"
        }
        return "\(formattedDate(start)) – \(formattedDate(end))"
    }

    static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }

    static func formattedHourRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    static func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
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

    static func downsampledChartPoints(
        _ points: [SleepForensicPDFExporter.ChartPoint],
        maxCount: Int
    ) -> [SleepForensicPDFExporter.ChartPoint] {
        guard points.count > maxCount else { return points }
        let stride = max(1, points.count / maxCount)
        return Swift.stride(from: 0, to: points.count, by: stride).map { points[$0] }
    }

    private static func measuredHeight(
        text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height
    }
}
