import SwiftData
import XCTest
@testable import NoiseRecord

@MainActor
final class SleepMeasurementPersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: SleepNoiseSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testLatestCompletedSessionOnDayFiltersByEndedAt() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todaySession = makeCompletedSession(
            startedAt: calendar.date(byAdding: .hour, value: -8, to: today)!,
            endedAt: calendar.date(byAdding: .hour, value: 7, to: today)!
        )
        let yesterdaySession = makeCompletedSession(
            startedAt: calendar.date(byAdding: .hour, value: -8, to: yesterday)!,
            endedAt: calendar.date(byAdding: .hour, value: 7, to: yesterday)!
        )

        context.insert(todaySession)
        context.insert(yesterdaySession)
        try context.save()

        let result = SleepMeasurementPersistence.latestCompletedSession(on: today, in: context)
        XCTAssertEqual(result?.id, todaySession.id)
    }

    func testLatestCompletedSessionOnDayReturnsNilWhenNoMatch() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdaySession = makeCompletedSession(
            startedAt: calendar.date(byAdding: .hour, value: -8, to: yesterday)!,
            endedAt: calendar.date(byAdding: .hour, value: 7, to: yesterday)!
        )
        context.insert(yesterdaySession)
        try context.save()

        XCTAssertNil(SleepMeasurementPersistence.latestCompletedSession(on: today, in: context))
    }

    private func makeCompletedSession(startedAt: Date, endedAt: Date) -> SleepNoiseSession {
        let session = SleepNoiseSession(startedAt: startedAt)
        session.sessionStatus = .completed
        session.endedAt = endedAt
        return session
    }
}
