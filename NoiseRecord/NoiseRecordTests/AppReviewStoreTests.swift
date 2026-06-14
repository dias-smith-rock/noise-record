import XCTest
@testable import NoiseRecord

final class AppReviewStoreTests: XCTestCase {
    private let promptKey = "appReview.hasShownFirstFilePrompt"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: promptKey)
        super.tearDown()
    }

    func testNoteEvidenceFileSavedPostsPromptOnce() {
        let promptExpectation = expectation(description: "prompt")
        let token = NotificationCenter.default.addObserver(
            forName: AppReviewStore.shouldPresentPromptNotification,
            object: nil,
            queue: nil
        ) { _ in
            promptExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        AppReviewStore.noteEvidenceFileSaved()
        wait(for: [promptExpectation], timeout: 1)
        XCTAssertTrue(AppReviewStore.hasShownReviewPrompt)

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

        AppReviewStore.noteEvidenceFileSaved()
        wait(for: [secondExpectation], timeout: 0.2)
    }
}
