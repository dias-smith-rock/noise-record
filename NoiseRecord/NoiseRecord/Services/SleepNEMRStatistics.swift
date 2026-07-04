import Foundation

enum SleepNEMRStatistics {
    struct HourlyResultRow: Sendable {
        let pointLabel: String
        let timeRange: String
        let leq: Float
        let lmax: Float
        let l90: Float
        let localLimit: Float
        let epaLDNSuggestion: String
        let compliance: ComplianceStatus
    }

    struct PeakAnalysisRow: Sendable {
        let pointLabel: String
        let exceedCount: Int
        let exceedTimestamps: [Date]
        let highestLmax: Float
        let peakThreshold: Float
        let compliance: ComplianceStatus
    }

    struct ConclusionSummary: Sendable {
        let overallConclusion: [String]
        let backgroundCorrectionNote: String
        let recommendations: [String]
        let anyHourlyExceedance: Bool
        let anyPeakExceedance: Bool
    }

    enum ComplianceStatus: String, Sendable {
        case pass = "Pass / 达标"
        case exceed = "Exceed / 超标"
        case nonCompliant = "Non-Compliant / 不符合"
    }

    static func reportNumber(for sessionID: UUID, monitoringDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: monitoringDate)
        let suffix = sessionID.uuidString.prefix(3).uppercased()
        return "NMR-\(day)-\(suffix)"
    }

    static func hourlyResults(
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        samples: [SleepForensicPDFExporter.SampleSnapshot],
        localLimit: Float = NoiseReferenceLimits.residentialNightDB
    ) -> [HourlyResultRow] {
        let end = session.endedAt ?? session.startedAt.addingTimeInterval(3600)
        let duration = max(end.timeIntervalSince(session.startedAt), 60)

        if duration < 3600 {
            return [makeHourlyRow(
                pointLabel: "P1",
                start: session.startedAt,
                end: end,
                samples: samples,
                session: session,
                localLimit: localLimit
            )]
        }

        var rows: [HourlyResultRow] = []
        var bucketStart = session.startedAt
        while bucketStart < end {
            let bucketEnd = min(bucketStart.addingTimeInterval(3600), end)
            let bucketSamples = samples.filter { $0.timestamp >= bucketStart && $0.timestamp < bucketEnd }
            rows.append(makeHourlyRow(
                pointLabel: "P1",
                start: bucketStart,
                end: bucketEnd,
                samples: bucketSamples,
                session: session,
                localLimit: localLimit
            ))
            bucketStart = bucketEnd
        }
        return rows
    }

    static func peakAnalysis(
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        anomalies: [SleepForensicPDFExporter.IncidentRow],
        localLimit: Float = NoiseReferenceLimits.residentialNightDB
    ) -> PeakAnalysisRow {
        let threshold = localLimit + 15
        let exceeding = anomalies.filter { $0.peakDB > threshold }
        let highest = exceeding.map(\.peakDB).max() ?? session.peakDB
        let compliance: ComplianceStatus = exceeding.isEmpty ? .pass : .nonCompliant
        return PeakAnalysisRow(
            pointLabel: "P1",
            exceedCount: exceeding.count,
            exceedTimestamps: exceeding.map(\.timestamp),
            highestLmax: highest,
            peakThreshold: threshold,
            compliance: compliance
        )
    }

    static func buildConclusion(
        hourlyRows: [HourlyResultRow],
        peakRow: PeakAnalysisRow,
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot
    ) -> ConclusionSummary {
        let exceedingHours = hourlyRows.filter { $0.compliance == .exceed }
        let primaryRow = hourlyRows.first
        let l90 = primaryRow?.l90 ?? session.noiseFloorDB
        let leq = primaryRow?.leq ?? session.overallLeq
        let localLimit = primaryRow?.localLimit ?? NoiseReferenceLimits.residentialNightDB

        var overall: [String] = []
        if let row = exceedingHours.first {
            overall.append(
                """
                6.1 Overall Conclusion / 总体结论: During the monitoring period, primary point \(row.pointLabel) recorded a 1-hour equivalent level of \(String(format: "%.1f", row.leq)) dB(A), exceeding the local nighttime residential limit of \(String(format: "%.0f", row.localLimit)) dB(A) and the EPA community noise guidance.
                """
            )
        } else if let row = primaryRow {
            overall.append(
                """
                6.1 Overall Conclusion / 总体结论: Primary point \(row.pointLabel) recorded a 1-hour equivalent level of \(String(format: "%.1f", row.leq)) dB(A), within the local nighttime residential limit of \(String(format: "%.0f", row.localLimit)) dB(A).
                """
            )
        }

        if peakRow.exceedCount > 0 {
            overall.append(
                """
                Impulsive peaks / 突发噪音显著: Point \(peakRow.pointLabel) recorded \(peakRow.exceedCount) instantaneous events above \(String(format: "%.0f", peakRow.peakThreshold)) dB(A), with a maximum of \(String(format: "%.1f", peakRow.highestLmax)) dB(A). These events indicate uncontrolled impulsive noise sources.
                """
            )
        } else {
            overall.append(
                "Impulsive peaks / 突发噪音: No instantaneous events exceeded \(String(format: "%.0f", peakRow.peakThreshold)) dB(A) during the session."
            )
        }

        let backgroundNote: String
        if leq - l90 > 10 {
            backgroundNote = """
            6.2 Background Correction / 背景噪音修正说明: Background level (L90 = \(String(format: "%.1f", l90)) dB(A)) is more than 10 dB(A) below the measured Leq (\(String(format: "%.1f", leq)) dB(A)). No background correction is required; exceedance determination remains valid.
            """
        } else {
            backgroundNote = """
            6.2 Background Correction / 背景噪音修正说明: Background level (L90 = \(String(format: "%.1f", l90)) dB(A)) is within 10 dB(A) of measured Leq (\(String(format: "%.1f", leq)) dB(A)). Professional background correction may be required for formal regulatory submission.
            """
        }

        let recommendations = [
            """
            6.3 Recommendations / 建议措施 — Construction management: Restrict high-noise equipment after 22:00; secure vehicle loading areas and prohibit unnecessary horn use.
            """,
            """
            Engineering noise control: Install or raise perimeter barriers with absorptive treatment near sensitive receptors; target 5–8 dB(A) path attenuation.
            """,
            """
            Follow-up monitoring: Repeat measurement within 7 days after corrective actions to verify compliance.
            """,
        ]

        return ConclusionSummary(
            overallConclusion: overall,
            backgroundCorrectionNote: backgroundNote,
            recommendations: recommendations,
            anyHourlyExceedance: !exceedingHours.isEmpty,
            anyPeakExceedance: peakRow.exceedCount > 0
        )
    }

    static func percentile90(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * 0.9).rounded())
        return sorted[min(max(index, 0), sorted.count - 1)]
    }

    private static func makeHourlyRow(
        pointLabel: String,
        start: Date,
        end: Date,
        samples: [SleepForensicPDFExporter.SampleSnapshot],
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        localLimit: Float
    ) -> HourlyResultRow {
        let decibels = samples.map { max($0.dbMax, $0.leq, $0.dbCurrent) }
        let leq: Float
        let lmax: Float
        let l90: Float

        if decibels.isEmpty {
            leq = session.overallLeq
            lmax = session.peakDB
            l90 = session.noiseFloorDB
        } else {
            leq = decibels.reduce(0, +) / Float(decibels.count)
            lmax = decibels.max() ?? session.peakDB
            l90 = percentile90(decibels)
        }

        let compliance: ComplianceStatus = leq > localLimit ? .exceed : .pass
        return HourlyResultRow(
            pointLabel: pointLabel,
            timeRange: ForensicPDFLayout.formattedHourRange(start: start, end: end),
            leq: leq,
            lmax: lmax,
            l90: l90,
            localLimit: localLimit,
            epaLDNSuggestion: "≤ 55",
            compliance: compliance
        )
    }
}
