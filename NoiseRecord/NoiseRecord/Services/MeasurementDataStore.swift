import Foundation
import SwiftData

enum MeasurementDataStore {
    private static let maxSampleCount = 86_400

    @MainActor
    static func pruneSamplesIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<MeasurementSample>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = maxSampleCount + 1
        guard let samples = try? context.fetch(descriptor), samples.count > maxSampleCount else { return }

        let overflow = samples.suffix(from: maxSampleCount)
        overflow.forEach { context.delete($0) }
        try? context.save()
    }

    @MainActor
    static func clearAllSamples(in context: ModelContext) throws {
        try context.delete(model: MeasurementSample.self)
        try context.save()
    }

    @MainActor
    static func sampleCount(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<MeasurementSample>())) ?? 0
    }
}
