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

    static func build(
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        locationSummary: String?,
        sampleCount: Int,
        copy: SleepNEMRCopy
    ) -> ReportFields {
        let endedAt = session.endedAt ?? session.startedAt
        let reportNumber = SleepNEMRStatistics.reportNumber(
            for: session.id,
            monitoringDate: session.startedAt
        )
        let siteAddress = locationSummary ?? copy.sitePlaceholder
        let monitoringFirm = HardwareIdentifier.pdfDeviceMetadataLine
        let environmentLine = SleepEnvironmentFormatter.pdfNEMRLine(
            start: session.startEnvironmentSnapshot,
            end: session.endEnvironmentSnapshot,
            copy: copy
        )
        let gpsLine = SleepLocationFormatter.pdfNEMRLine(
            fromResolvedSummary: locationSummary,
            copy: copy
        )

        return ReportFields(
            reportNumber: reportNumber,
            monitoringDateRange: ForensicPDFLayout.formattedDateRange(start: session.startedAt, end: endedAt),
            reportDate: ForensicPDFLayout.formattedDate(Date()),
            client: copy.clientPlaceholder,
            siteAddress: siteAddress,
            purpose: copy.purposeValue,
            monitoringFirm: monitoringFirm,
            introductionParagraph: copy.introduction(
                client: copy.clientPlaceholder,
                firm: monitoringFirm,
                monitoringDate: ForensicPDFLayout.formattedDate(session.startedAt),
                siteAddress: siteAddress
            ),
            instrumentationRows: instrumentationRows(
                for: session,
                environmentLine: environmentLine,
                gpsLine: gpsLine,
                copy: copy
            ),
            methodologyRows: methodologyRows(
                session: session,
                endedAt: endedAt,
                sampleCount: sampleCount,
                copy: copy
            ),
            locationTableRows: locationRows(siteAddress: siteAddress, copy: copy)
        )
    }

    private static func instrumentationRows(
        for session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        environmentLine: String,
        gpsLine: String,
        copy: SleepNEMRCopy
    ) -> [(String, String)] {
        let weighting: String
        if session.isHighSensitivitySession {
            weighting = copy.weightingZ
        } else if session.weightingMode == WeightingType.c.rawValue {
            weighting = copy.weightingC
        } else {
            weighting = copy.weightingA
        }

        let calibrationText: String
        if DeviceCalibrationStore.userAdjustment != 0 {
            calibrationText = copy.calibrationUserOffset(
                offset: DeviceCalibrationStore.userAdjustment,
                referenceSPL: DeviceCalibrationStore.referenceSPL
            )
        } else {
            calibrationText = copy.calibrationFactory
        }

        return [
            (copy.labelSoundLevelMeter, "\(HardwareIdentifier.pdfHardwareDescription) · Decibel Meter Pro"),
            (copy.labelWeighting, weighting),
            (copy.labelTimeResponse, copy.timeResponseValue),
            (copy.labelCalibrator, copy.calibratorValue),
            (copy.labelCalibrationRecord, calibrationText),
            (copy.labelTemperatureHumidity, environmentLine),
            (copy.labelGPS, gpsLine),
        ]
    }

    private static func methodologyRows(
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        endedAt: Date,
        sampleCount: Int,
        copy: SleepNEMRCopy
    ) -> [(String, String)] {
        [
            (
                copy.labelMonitoringWindow,
                "\(ForensicPDFLayout.formattedDateTime(session.startedAt)) – \(ForensicPDFLayout.formattedDateTime(endedAt))"
            ),
            (
                copy.labelMeasurementDuration,
                copy.measurementDurationValue(
                    ForensicPDFLayout.formattedDuration(max(0, endedAt.timeIntervalSince(session.startedAt)))
                )
            ),
            (
                copy.labelSamplingInterval,
                copy.samplingIntervalValue(
                    seconds: Int(SleepMeasurementPersistence.sampleInterval),
                    sampleCount: sampleCount
                )
            ),
            (
                copy.labelSiteMap,
                copy.siteMapPlaceholder
            ),
        ]
    }

    private static func locationRows(siteAddress: String, copy: SleepNEMRCopy) -> [(String, String, String)] {
        [
            (
                "P1",
                copy.locationDescription(siteAddress: siteAddress),
                copy.locationSource
            ),
        ]
    }
}
