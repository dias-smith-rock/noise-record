#if DEBUG
import Foundation
import SwiftData

/// DEBUG 专用：为 7 日历史 / 晨报 UI 注入示例睡眠会话。
enum SleepDebugMockData {
    private struct NightProfile {
        let daysAgo: Int
        let overallLeq: Float
        let noiseFloorDB: Float
        let peakDB: Float
        let anomalySpecs: [(hoursAfterStart: Double, peakDB: Float, durationSeconds: Float, hint: SleepImpactHint)]
        let isReportRead: Bool
        let isHighSensitivity: Bool
        let durationHours: Double
    }

    private static let profiles: [NightProfile] = [
        NightProfile(
            daysAgo: 0,
            overallLeq: 32,
            noiseFloorDB: 28,
            peakDB: 44,
            anomalySpecs: [],
            isReportRead: false,
            isHighSensitivity: false,
            durationHours: 7.5
        ),
        NightProfile(
            daysAgo: 1,
            overallLeq: 40,
            noiseFloorDB: 34,
            peakDB: 58,
            anomalySpecs: [
                (2.5, 58, 3.5, .deepSleep),
                (5.0, 52, 2.0, .lightSleep),
            ],
            isReportRead: true,
            isHighSensitivity: false,
            durationHours: 8.0
        ),
        NightProfile(
            daysAgo: 2,
            overallLeq: 50,
            noiseFloorDB: 42,
            peakDB: 68,
            anomalySpecs: [
                (1.0, 62, 4.0, .deepSleep),
                (3.5, 68, 5.0, .deepSleep),
                (6.0, 55, 2.5, .lightSleep),
            ],
            isReportRead: true,
            isHighSensitivity: true,
            durationHours: 6.5
        ),
        NightProfile(
            daysAgo: 3,
            overallLeq: 30,
            noiseFloorDB: 26,
            peakDB: 42,
            anomalySpecs: [],
            isReportRead: true,
            isHighSensitivity: false,
            durationHours: 7.0
        ),
        NightProfile(
            daysAgo: 4,
            overallLeq: 58,
            noiseFloorDB: 48,
            peakDB: 72,
            anomalySpecs: [
                (0.5, 70, 6.0, .deepSleep),
                (2.0, 65, 4.0, .deepSleep),
                (4.0, 72, 3.0, .lightSleep),
                (5.5, 60, 2.0, .lightSleep),
            ],
            isReportRead: false,
            isHighSensitivity: false,
            durationHours: 5.0
        ),
        NightProfile(
            daysAgo: 5,
            overallLeq: 38,
            noiseFloorDB: 32,
            peakDB: 54,
            anomalySpecs: [
                (4.5, 54, 2.5, .lightSleep),
            ],
            isReportRead: true,
            isHighSensitivity: false,
            durationHours: 7.25
        ),
        NightProfile(
            daysAgo: 6,
            overallLeq: 47,
            noiseFloorDB: 40,
            peakDB: 63,
            anomalySpecs: [
                (2.0, 60, 3.0, .deepSleep),
                (5.0, 63, 4.5, .lightSleep),
            ],
            isReportRead: true,
            isHighSensitivity: false,
            durationHours: 6.75
        ),
    ]

    /// 模拟器上无已完成会话时自动注入；真机可通过 Launch Argument `-SeedSleepMockData` 启用。
    static var shouldAutoSeed: Bool {
        if ProcessInfo.processInfo.arguments.contains("-SeedSleepMockData") {
            return true
        }
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        guard shouldAutoSeed else { return }
        guard SleepMeasurementPersistence.recentSessions(limit: 1, in: context).isEmpty else { return }
        seedMockSessions(in: context)
    }

    @MainActor
    @discardableResult
    static func seedMockSessions(in context: ModelContext) -> Int {
        clearAllSleepSessions(in: context)

        let calendar = Calendar.current
        var inserted = 0

        for profile in profiles {
            guard let startedAt = calendar.date(
                byAdding: .day,
                value: -profile.daysAgo,
                to: calendar.startOfDay(for: Date())
            ) else { continue }

            let bedtime = calendar.date(bySettingHour: 23, minute: 15, second: 0, of: startedAt) ?? startedAt
            let endedAt = bedtime.addingTimeInterval(profile.durationHours * 3600)

            let session = SleepNoiseSession(startedAt: bedtime)
            session.endedAt = endedAt
            session.sessionStatus = .completed
            session.overallLeq = profile.overallLeq
            session.noiseFloorDB = profile.noiseFloorDB
            session.peakDB = profile.peakDB
            session.anomalyCount = profile.anomalySpecs.count
            session.grade = SilenceGrade.from(leq: profile.overallLeq).rawValue
            session.isReportRead = profile.isReportRead
            session.weightingMode = profile.isHighSensitivity ? "highSensitivity" : WeightingType.a.rawValue

            let anomalyCandidates = profile.anomalySpecs.map { spec in
                SleepAnomalyCandidate(
                    timestamp: bedtime.addingTimeInterval(spec.hoursAfterStart * 3600),
                    peakDB: spec.peakDB,
                    durationSeconds: spec.durationSeconds
                )
            }

            session.anomalies = anomalyCandidates.map { candidate in
                SleepAnomalyEvent(
                    timestamp: candidate.timestamp,
                    peakDB: candidate.peakDB,
                    durationSeconds: candidate.durationSeconds,
                    sleepImpactHint: SleepNoiseAnalyzer.sleepImpactHint(for: candidate.timestamp)
                )
            }

            session.reportSummary = SleepReportBuilder.buildSummary(
                overallLeq: profile.overallLeq,
                noiseFloor: profile.noiseFloorDB,
                anomalies: anomalyCandidates,
                calendar: calendar
            )

            insertMockMeasurementSamples(
                for: session,
                bedtime: bedtime,
                endedAt: endedAt,
                profile: profile,
                in: context
            )

            context.insert(session)
            inserted += 1
        }

        try? context.save()
        return inserted
    }

    @MainActor
    private static func insertMockMeasurementSamples(
        for session: SleepNoiseSession,
        bedtime: Date,
        endedAt: Date,
        profile: NightProfile,
        in context: ModelContext
    ) {
        let duration = endedAt.timeIntervalSince(bedtime)
        guard duration > 0 else { return }

        let interval = SleepMeasurementPersistence.sampleInterval
        var time = bedtime
        var index = 0

        while time <= endedAt {
            let progress = time.timeIntervalSince(bedtime) / duration
            var db = profile.noiseFloorDB + (profile.overallLeq - profile.noiseFloorDB) * Float(0.12 + 0.08 * sin(progress * .pi * 6))

            for spec in profile.anomalySpecs {
                let anomalyTime = bedtime.addingTimeInterval(spec.hoursAfterStart * 3600)
                let delta = abs(time.timeIntervalSince(anomalyTime))
                let window = max(Double(spec.durationSeconds), 30)
                if delta < window {
                    let influence = Float(1 - delta / window)
                    db = max(db, profile.noiseFloorDB + (spec.peakDB - profile.noiseFloorDB) * influence)
                }
            }

            db = min(max(db, profile.noiseFloorDB - 2), profile.peakDB)
            let weighting = profile.isHighSensitivity ? "highSensitivity" : WeightingType.a.rawValue

            context.insert(
                MeasurementSample(
                    timestamp: time,
                    dbCurrent: db,
                    dbMax: min(db + 1.5, profile.peakDB),
                    dbMin: max(db - 1.5, profile.noiseFloorDB),
                    dbAvg: db,
                    leq: db,
                    weighting: weighting,
                    sleepSessionID: session.id
                )
            )

            time = time.addingTimeInterval(interval)
            index += 1
            if index > 500 { break }
        }
    }

    @MainActor
    static func clearAllSleepSessions(in context: ModelContext) {
        let descriptor = FetchDescriptor<SleepNoiseSession>()
        guard let sessions = try? context.fetch(descriptor) else { return }
        for session in sessions {
            context.delete(session)
        }
        try? context.save()
        SleepMonitorSettingsStore.pendingReportSessionID = nil
    }
}
#endif
