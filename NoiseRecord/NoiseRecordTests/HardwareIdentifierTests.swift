import XCTest
@testable import NoiseRecord

final class HardwareIdentifierTests: XCTestCase {
    func testMarketingNameForIPhone13() {
        XCTAssertEqual(HardwareIdentifier.marketingName(for: "iPhone14,5"), "iPhone 13")
    }

    func testMarketingNameForIPhone14() {
        XCTAssertEqual(HardwareIdentifier.marketingName(for: "iPhone14,7"), "iPhone 14")
    }

    func testMarketingNameForIPhone13Mini() {
        XCTAssertEqual(HardwareIdentifier.marketingName(for: "iPhone14,4"), "iPhone 13 mini")
    }

    func testMarketingNameFallsBackToMachineIdentifier() {
        XCTAssertEqual(HardwareIdentifier.marketingName(for: "iPhone99,1"), "iPhone99,1")
    }

    func testPDFDeviceMetadataDoesNotUseMicrophoneArrayWording() {
        XCTAssertFalse(HardwareIdentifier.pdfDeviceMetadataLine.localizedCaseInsensitiveContains("Microphone Array"))
        XCTAssertFalse(HardwareIdentifier.pdfCollectionPersonnelLine.localizedCaseInsensitiveContains("Microphone Array"))
        XCTAssertTrue(HardwareIdentifier.pdfDeviceMetadataLine.contains("built-in microphone"))
    }

    func testPDFHardwareDescriptionUsesConsumerFallbackForUnknownDevice() {
        let description = HardwareIdentifier.pdfHardwareDescription
        XCTAssertFalse(description.localizedCaseInsensitiveContains("Omni-Directional"))
    }
}
