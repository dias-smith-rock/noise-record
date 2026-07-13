import Foundation

enum SleepNEMRReportMetadata {
    struct ReportFields: Sendable {
        let reportNumber: String
        let monitoringDateRange: String
        let reportDate: String
        let client: String
        let siteAddress: String
        let purpose: String
        let monitoringFirm: String
        let introductionParagraph: String
        let instrumentationRows: [(String, String)]
        let methodologyRows: [(String, String)]
        let locationTableRows: [(String, String, String)]
    }

    static let clientPlaceholder = "[委托方名称/地址 / Client Name & Address]"
    static let sitePlaceholder = "[项目具体地址 / Site Address]"
    static let firmPlaceholder = "[公司名称及资质 / Monitoring Firm & Credentials]"
    static let siteMapPlaceholder = "[Site map not included / 未附平面图]"

    static func build(
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        locationSummary: String?,
        sampleCount: Int
    ) -> ReportFields {
        let endedAt = session.endedAt ?? session.startedAt
        let reportNumber = SleepNEMRStatistics.reportNumber(
            for: session.id,
            monitoringDate: session.startedAt
        )
        let siteAddress = locationSummary ?? sitePlaceholder
        let monitoringFirm = HardwareIdentifier.pdfDeviceMetadataLine
        let environmentLine = SleepEnvironmentFormatter.pdfNEMRLine(
            start: session.startEnvironmentSnapshot,
            end: session.endEnvironmentSnapshot
        )
        let gpsLine = SleepLocationFormatter.pdfNEMRLine(fromResolvedSummary: locationSummary)

        return ReportFields(
            reportNumber: reportNumber,
            monitoringDateRange: ForensicPDFLayout.formattedDateRange(start: session.startedAt, end: endedAt),
            reportDate: ForensicPDFLayout.formattedDate(Date()),
            client: clientPlaceholder,
            siteAddress: siteAddress,
            purpose: "Nighttime construction noise compliance assessment / residential noise complaint investigation / environmental baseline survey",
            monitoringFirm: monitoringFirm,
            introductionParagraph: introductionText(
                client: clientPlaceholder,
                firm: monitoringFirm,
                monitoringDate: ForensicPDFLayout.formattedDate(session.startedAt),
                siteAddress: siteAddress
            ),
            instrumentationRows: instrumentationRows(
                for: session,
                environmentLine: environmentLine,
                gpsLine: gpsLine
            ),
            methodologyRows: methodologyRows(
                session: session,
                endedAt: endedAt,
                sampleCount: sampleCount
            ),
            locationTableRows: locationRows(siteAddress: siteAddress)
        )
    }

    private static func introductionText(
        client: String,
        firm: String,
        monitoringDate: String,
        siteAddress: String
    ) -> String {
        """
        本报告受 \(client) 委托，由 \(firm) 于 \(monitoringDate) 对 \(siteAddress) 周边声环境进行夜间噪声监测。监测旨在评估该区域夜间（22:00 – 07:00）噪音水平是否符合联邦及地方相关标准。

        This report was commissioned by \(client) and performed by \(firm) on \(monitoringDate) at \(siteAddress). The objective is to evaluate whether nighttime (22:00 – 07:00) noise levels comply with applicable federal and local standards.
        """
    }

    private static func instrumentationRows(
        for session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        environmentLine: String,
        gpsLine: String
    ) -> [(String, String)] {
        let weighting: String
        if session.isHighSensitivitySession {
            weighting = "dBZ High-Sensitivity (full-band; not ANSI Type 1 certified)"
        } else if session.weightingMode == WeightingType.c.rawValue {
            weighting = "C-weighting (not ANSI Type 1 certified)"
        } else {
            weighting = "A-weighting (not ANSI Type 1 certified)"
        }

        let calibrationText: String
        if DeviceCalibrationStore.userAdjustment != 0 {
            calibrationText = String(
                format: "User calibration offset: %+.1f dB (reference SPL %.0f dB). Consumer iOS device — not ANSI Type 1 certified.",
                DeviceCalibrationStore.userAdjustment,
                DeviceCalibrationStore.referenceSPL
            )
        } else {
            calibrationText = "Factory device offset applied. No user field calibration recorded. Consumer iOS device — not ANSI Type 1 certified."
        }

        return [
            ("Sound Level Meter / 声级计", "\(HardwareIdentifier.pdfHardwareDescription) · Decibel Meter Pro"),
            ("Weighting / 频率加权", weighting),
            ("Time Response / 时间响应", "Fast / equivalent continuous (Leq) integration"),
            ("Acoustic Calibrator / 声校准器", "Not used — consumer device calibration only / 未使用标准声校准器"),
            ("Calibration Record / 校准记录", calibrationText),
            ("Temperature / Humidity / 温度与湿度", environmentLine),
            ("GPS Coordinates / GPS 坐标", gpsLine),
        ]
    }

    private static func methodologyRows(
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        endedAt: Date,
        sampleCount: Int
    ) -> [(String, String)] {
        [
            (
                "Monitoring Window / 监测时段",
                "\(ForensicPDFLayout.formattedDateTime(session.startedAt)) – \(ForensicPDFLayout.formattedDateTime(endedAt))"
            ),
            (
                "Measurement Duration / 测量时长",
                "\(ForensicPDFLayout.formattedDuration(max(0, endedAt.timeIntervalSince(session.startedAt)))) continuous monitoring"
            ),
            (
                "Sampling Interval / 数据记录间隔",
                "Approximately \(Int(SleepMeasurementPersistence.sampleInterval)) seconds (\(sampleCount) logged samples)"
            ),
            (
                "Site Map / 附图",
                siteMapPlaceholder
            ),
        ]
    }

    private static func locationRows(siteAddress: String) -> [(String, String, String)] {
        [
            (
                "P1",
                "Primary monitoring point at \(siteAddress); microphone at typical indoor/bedroom height via handheld device",
                "Local environmental noise affecting sensitive receptor"
            ),
        ]
    }
}
