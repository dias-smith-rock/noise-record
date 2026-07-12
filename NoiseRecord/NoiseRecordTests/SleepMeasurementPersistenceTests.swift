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

    func testEnvironmentFieldsPersistOnSleepSession() throws {
        let session = makeCompletedSession(
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(3600)
        )
        session.startTemperatureCelsius = 22.5
        session.startHumidityPercent = 65
        session.endTemperatureCelsius = 21.0
        session.endHumidityPercent = 70

        context.insert(session)
        try context.save()

        let sessionID = session.id
        let descriptor = FetchDescriptor<SleepNoiseSession>(
            predicate: #Predicate { $0.id == sessionID }
        )
        let fetched = try context.fetch(descriptor).first

        XCTAssertEqual(fetched?.startTemperatureCelsius, 22.5)
        XCTAssertEqual(fetched?.startHumidityPercent, 65)
        XCTAssertEqual(fetched?.endTemperatureCelsius, 21.0)
        XCTAssertEqual(fetched?.endHumidityPercent, 70)
    }
}
