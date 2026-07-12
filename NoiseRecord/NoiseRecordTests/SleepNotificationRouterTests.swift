import XCTest
@testable import NoiseRecord

final class SleepNotificationRouterTests: XCTestCase {
    override func tearDown() {
        SleepNotificationRouter.resetForTesting()
        super.tearDown()
    }

    func testParsesWakeReportIdentifier() {
        let action = SleepNotificationRouter.parse(
            identifier: SleepNotificationRouter.wakeReportIdentifier,
            userInfo: [:]
        )
        XCTAssertEqual(action, .openTodayReport)
    }

    func testParsesWakeReportUserInfoAction() {
        let action = SleepNotificationRouter.parse(
            identifier: "unknown",
            userInfo: [SleepNotificationRouter.actionKey: SleepNotificationRouter.actionOpenTodayReport]
        )
        XCTAssertEqual(action, .openTodayReport)
    }

    func testParsesBedtimeReminderIdentifier() {
        let action = SleepNotificationRouter.parse(
            identifier: SleepNotificationRouter.bedtimeReminderIdentifier,
            userInfo: [:]
        )
        XCTAssertEqual(action, .startSleepMonitoring)
    }

    func testParsesOvernightActivationIdentifier() {
        let action = SleepNotificationRouter.parse(
            identifier: SleepNotificationRouter.overnightActivationIdentifier,
            userInfo: [:]
        )
        XCTAssertEqual(action, .startSleepMonitoring)
    }

    func testParsesImmediateReportFromUserInfo() {
        let sessionID = UUID()
        let action = SleepNotificationRouter.parse(
            identifier: "sleep.report.\(sessionID.uuidString)",
            userInfo: [LiveActivityDeepLink.sessionIDKey: sessionID.uuidString]
        )
        XCTAssertEqual(action, .openReport(sessionID))
    }

    func testParsesImmediateReportFromIdentifierWhenUserInfoMissing() {
        let sessionID = UUID()
        let action = SleepNotificationRouter.parse(
            identifier: "sleep.report.\(sessionID.uuidString)",
            userInfo: [:]
        )
        XCTAssertEqual(action, .openReport(sessionID))
    }

    func testConsumePendingActionOnlyOnce() {
        let sessionID = UUID()
        SleepNotificationRouter.storePendingActionForTesting(.openReport(sessionID))

        XCTAssertEqual(SleepNotificationRouter.consumePendingAction(), .openReport(sessionID))
        XCTAssertNil(SleepNotificationRouter.consumePendingAction())
    }
}
