import Foundation
import SwiftData

enum MeasurementDataStore {
    private static let maxSampleCount = 86_400

    @MainActor
    static func pruneSamplesIfNeeded(in context: ModelContext) {
        let total = sampleCount(in: context)
        guard total > maxSampleCount else { return }

        let deleteCount = total - maxSampleCount
        var descriptor = FetchDescriptor<MeasurementSample>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = deleteCount
        guard let oldest = try? context.fetch(descriptor), !oldest.isEmpty else { return }

        oldest.forEach { context.delete($0) }
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
