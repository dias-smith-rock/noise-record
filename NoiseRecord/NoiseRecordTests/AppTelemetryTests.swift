import XCTest
@testable import NoiseRecord

final class AppTelemetryTests: XCTestCase {
    func testTruncatedAnalyticsValueLimitsLength() {
        let longValue = String(repeating: "a", count: 150)
        let truncated = AppTelemetry.truncatedAnalyticsValue(longValue)
        XCTAssertEqual(truncated.count, AppTelemetry.maxAnalyticsParameterLength)
    }

    func testSanitizedAnalyticsParametersRespectsMaxCount() {
        let parameters = [
            "one": "1",
            "two": "2",
            "three": "3",
            "four": "4",
            "five": "5",
            "six": "6",
        ]
        let sanitized = AppTelemetry.sanitizedAnalyticsParameters(parameters)
        XCTAssertEqual(sanitized?.count, AppTelemetry.maxAnalyticsParameterCount)
    }

    func testSanitizedAnalyticsParametersTruncatesValues() {
        let parameters = ["message": String(repeating: "x", count: 120)]
        let sanitized = AppTelemetry.sanitizedAnalyticsParameters(parameters)
        let value = sanitized?["message"] as? String
        XCTAssertEqual(value?.count, AppTelemetry.maxAnalyticsParameterLength)
    }

    func testCommercialAdOutcomeWhitelist() {
        XCTAssertEqual(AppTelemetry.commercialAdOutcome(for: "show_presenting"), "show")
        XCTAssertEqual(AppTelemetry.commercialAdOutcome(for: "dismissed"), "dismiss")
        XCTAssertEqual(AppTelemetry.commercialAdOutcome(for: "load_failed"), "fail")
        XCTAssertNil(AppTelemetry.commercialAdOutcome(for: "load_skipped_already_loading"))
        XCTAssertNil(AppTelemetry.commercialAdOutcome(for: "armed_on_cold_start"))
    }

    func testCommercialIAPOutcomeWhitelist() {
        XCTAssertEqual(AppTelemetry.commercialIAPOutcome(for: "purchase_verified"), "purchase_success")
        XCTAssertEqual(AppTelemetry.commercialIAPOutcome(for: "restore_succeeded"), "restore_success")
        XCTAssertEqual(AppTelemetry.commercialIAPOutcome(for: "product_load_not_found"), "product_missing")
        XCTAssertNil(AppTelemetry.commercialIAPOutcome(for: "purchase_started"))
        XCTAssertNil(AppTelemetry.commercialIAPOutcome(for: "purchase_user_cancelled"))
    }

    func testClickEventParametersAreSanitized() {
        let parameters = AppTelemetry.sanitizedAnalyticsParameters([
            "tab": "monitor",
            "action": "start",
            "context": "sleep_export",
            "format": "legacyOvernight",
            "tier": "yearly",
            "overflow": "ignored",
        ])
        XCTAssertEqual(parameters?.count, AppTelemetry.maxAnalyticsParameterCount)
        XCTAssertEqual(parameters?["action"] as? String, "start")
        XCTAssertEqual(parameters?["tab"] as? String, "monitor")
        XCTAssertNil(parameters?["tier"])
    }
}
