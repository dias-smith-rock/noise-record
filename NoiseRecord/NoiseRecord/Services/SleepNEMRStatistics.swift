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

    enum ComplianceStatus: String, Sendable, Equatable {
        case pass
        case exceed
        case nonCompliant
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
        session: SleepForensicPDFExporter.SleepNoiseSessionSnapshot,
        copy: SleepNEMRCopy
    ) -> ConclusionSummary {
        let exceedingHours = hourlyRows.filter { $0.compliance == .exceed }
        let primaryRow = hourlyRows.first
        let l90 = primaryRow?.l90 ?? session.noiseFloorDB
        let leq = primaryRow?.leq ?? session.overallLeq

        var overall: [String] = []
        if let row = exceedingHours.first {
            overall.append(
                copy.conclusionExceed(point: row.pointLabel, leq: row.leq, limit: row.localLimit)
            )
        } else if let row = primaryRow {
            overall.append(
                copy.conclusionWithin(point: row.pointLabel, leq: row.leq, limit: row.localLimit)
            )
        }

        if peakRow.exceedCount > 0 {
            overall.append(
                copy.conclusionPeaksSignificant(
                    point: peakRow.pointLabel,
                    count: peakRow.exceedCount,
                    threshold: peakRow.peakThreshold,
                    max: peakRow.highestLmax
                )
            )
        } else {
            overall.append(copy.conclusionPeaksNone(threshold: peakRow.peakThreshold))
        }

        let backgroundNote: String
        if leq - l90 > 10 {
            backgroundNote = copy.backgroundNoCorrection(l90: l90, leq: leq)
        } else {
            backgroundNote = copy.backgroundNeedsCorrection(l90: l90, leq: leq)
        }

        let recommendations = [
            copy.recommendationConstruction,
            copy.recommendationEngineering,
            copy.recommendationFollowUp,
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
        let decibels = samples.map { $0.leq > 0 ? $0.leq : $0.dbCurrent }
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
