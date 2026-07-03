import Foundation
import SwiftData

enum SleepMeasurementPersistence {
    static let sampleInterval: TimeInterval = 30

    @MainActor
    static func persistSample(
        engine: NoiseMonitorEngine,
        sleepSessionID: UUID,
        in context: ModelContext
    ) {
        let sample = MeasurementSample(
            timestamp: Date(),
            dbCurrent: engine.currentDB,
            dbMax: engine.maxDB,
            dbMin: engine.minDB,
            dbAvg: engine.averageDB,
            leq: engine.leq,
            weighting: engine.effectiveWeighting.rawValue,
            noiseType: engine.latestNoiseLabel,
            sleepSessionID: sleepSessionID
        )
        context.insert(sample)
        try? context.save()
        MeasurementDataStore.pruneSamplesIfNeeded(in: context)
    }

    @MainActor
    static func samples(
        for sleepSessionID: UUID,
        in context: ModelContext
    ) -> [MeasurementSample] {
        let targetID = sleepSessionID
        let descriptor = FetchDescriptor<MeasurementSample>(
            predicate: #Predicate { $0.sleepSessionID == targetID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func recentSessions(
        limit: Int,
        in context: ModelContext
    ) -> [SleepNoiseSession] {
        let completed = SleepNoiseSessionStatus.completed.rawValue
        var descriptor = FetchDescriptor<SleepNoiseSession>(
            predicate: #Predicate { $0.status == completed },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func latestCompletedSession(in context: ModelContext) -> SleepNoiseSession? {
        recentSessions(limit: 1, in: context).first
    }

    @MainActor
    static func sessions(
        since date: Date,
        in context: ModelContext
    ) -> [SleepNoiseSession] {
        let completed = SleepNoiseSessionStatus.completed.rawValue
        let descriptor = FetchDescriptor<SleepNoiseSession>(
            predicate: #Predicate { $0.startedAt >= date && $0.status == completed },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
