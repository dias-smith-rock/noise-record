import XCTest
@testable import NoiseRecord

final class AppReviewStoreTests: XCTestCase {
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suiteName = "AppReviewStoreTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        AppReviewStore.configure(defaults: testDefaults)
        AppReviewStore.resetForTesting()
    }

    override func tearDown() {
        AppReviewStore.resetForTesting()
        if let suiteName = testDefaults.volatileDomainNames.first {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        AppReviewStore.configure(defaults: .standard)
        super.tearDown()
    }

    func testMonitoringThresholdPostsPromptWhenNotBusy() {
        AppReviewStore.recordMonitoringElapsed(30)
        XCTAssertFalse(AppReviewStore.hasUsedCoreFeature)

        let promptExpectation = expectation(description: "prompt")
        let token = NotificationCenter.default.addObserver(
            forName: AppReviewStore.shouldPresentPromptNotification,
            object: nil,
            queue: nil
        ) { _ in
            promptExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        AppReviewStore.recordMonitoringElapsed(30)
        XCTAssertTrue(AppReviewStore.hasUsedCoreFeature)
        AppReviewStore.evaluatePromptIfEligible(isBusy: false)

        wait(for: [promptExpectation], timeout: 1)
        AppReviewStore.markReviewPromptPresented()
        XCTAssertTrue(AppReviewStore.hasShownReviewPrompt)
    }

    func testBusyStateDefersPrompt() {
        AppReviewStore.noteCoreFeatureUsed(.evidenceSaved)

        let promptExpectation = expectation(description: "no prompt while busy")
        promptExpectation.isInverted = true
        let token = NotificationCenter.default.addObserver(
            forName: AppReviewStore.shouldPresentPromptNotification,
            object: nil,
            queue: nil
        ) { _ in
            promptExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        AppReviewStore.evaluatePromptIfEligible(isBusy: true)
        wait(for: [promptExpectation], timeout: 0.2)
        XCTAssertFalse(AppReviewStore.hasShownReviewPrompt)

        let laterExpectation = expectation(description: "prompt after idle")
        let laterToken = NotificationCenter.default.addObserver(
            forName: AppReviewStore.shouldPresentPromptNotification,
            object: nil,
            queue: nil
        ) { _ in
            laterExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(laterToken) }

        AppReviewStore.evaluatePromptIfEligible(isBusy: false)
        wait(for: [laterExpectation], timeout: 1)
    }

    func testCoreFeatureKindsMarkUsedOnce() {
        for kind in AppReviewStore.CoreFeatureKind.allCases {
            AppReviewStore.resetForTesting()
            AppReviewStore.noteCoreFeatureUsed(kind)
            XCTAssertTrue(AppReviewStore.hasUsedCoreFeature)
            AppReviewStore.noteCoreFeatureUsed(kind)
        }
    }

    func testEvaluatePostsPromptOnlyOnce() {
        AppReviewStore.noteCoreFeatureUsed(.fullscreenLED)

        let firstExpectation = expectation(description: "first prompt")
        let token = NotificationCenter.default.addObserver(
            forName: AppReviewStore.shouldPresentPromptNotification,
            object: nil,
            queue: nil
        ) { _ in
            firstExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        AppReviewStore.evaluatePromptIfEligible(isBusy: false)
        wait(for: [firstExpectation], timeout: 1)
        AppReviewStore.markReviewPromptPresented()

        let secondExpectation = expectation(description: "no second prompt")
        secondExpectation.isInverted = true
        let secondToken = NotificationCenter.default.addObserver(
            forName: AppReviewStore.shouldPresentPromptNotification,
            object: nil,
            queue: nil
        ) { _ in
            secondExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(secondToken) }

        AppReviewStore.noteCoreFeatureUsed(.sleepReport)
        AppReviewStore.evaluatePromptIfEligible(isBusy: false)
        wait(for: [secondExpectation], timeout: 0.2)
    }
}
