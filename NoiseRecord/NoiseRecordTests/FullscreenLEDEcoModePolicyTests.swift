import XCTest
@testable import NoiseRecord

final class FullscreenLEDEcoModePolicyTests: XCTestCase {
    func testSignificantDecibelChangeThresholdIsThree() {
        XCTAssertEqual(FullscreenLEDEcoModePolicy.significantDecibelChangeThreshold, 3)
    }

    func testShouldRefreshWhenDeltaMeetsThreshold() {
        XCTAssertTrue(
            FullscreenLEDEcoModePolicy.shouldRefreshThrottledDecibel(current: 68, displayed: 65)
        )
        XCTAssertFalse(
            FullscreenLEDEcoModePolicy.shouldRefreshThrottledDecibel(current: 67.5, displayed: 65)
        )
    }

    func testDecibelRefreshIntervalIsOneMinute() {
        XCTAssertEqual(FullscreenLEDEcoModePolicy.decibelRefreshInterval, 60)
    }

    func testClockAndSpectrumIntervals() {
        XCTAssertEqual(FullscreenLEDEcoModePolicy.clockRefreshInterval, 60)
        XCTAssertEqual(FullscreenLEDEcoModePolicy.waveformSnapshotInterval, 12)
    }

    func testStartOfCurrentMinute() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 52, second: 37))!
        let start = FullscreenLEDEcoModePolicy.startOfCurrentMinute(for: date, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 52))!

        XCTAssertEqual(start, expected)
    }

    func testShouldRefreshClockWhenMinuteOrHourChanges() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let displayed = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 51))!
        let sameMinute = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 51, second: 45))!
        let nextMinute = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 52))!

        XCTAssertFalse(
            FullscreenLEDEcoModePolicy.shouldRefreshClock(current: sameMinute, displayed: displayed, calendar: calendar)
        )
        XCTAssertTrue(
            FullscreenLEDEcoModePolicy.shouldRefreshClock(current: nextMinute, displayed: displayed, calendar: calendar)
        )
    }

    func testSecondsUntilNextMinuteBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let atMinuteStart = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 52, second: 0))!
        let fifteenSecondsIn = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 51, second: 15))!

        XCTAssertEqual(
            FullscreenLEDEcoModePolicy.secondsUntilNextMinuteBoundary(from: atMinuteStart, calendar: calendar),
            60,
            accuracy: 0.001
        )
        XCTAssertEqual(
            FullscreenLEDEcoModePolicy.secondsUntilNextMinuteBoundary(from: fifteenSecondsIn, calendar: calendar),
            45,
            accuracy: 0.001
        )
    }
}
