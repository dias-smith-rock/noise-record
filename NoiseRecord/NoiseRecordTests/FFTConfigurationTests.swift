import XCTest
@testable import NoiseRecord

final class FFTConfigurationTests: XCTestCase {
    func testStandardResolutionAt44_1kHz() {
        XCTAssertEqual(FFTConfiguration.standard.fftSize, 1024)
        XCTAssertEqual(FFTConfiguration.standard.binCount, 512)
        XCTAssertEqual(FFTConfiguration.standard.log2n, 10)
        XCTAssertEqual(
            FFTConfiguration.standard.frequencyResolutionAt44_1kHz,
            44_100 / 1024,
            accuracy: 0.001
        )
    }

    func testAdvancedResolutionAt44_1kHz() {
        XCTAssertEqual(FFTConfiguration.advanced.fftSize, 2048)
        XCTAssertEqual(FFTConfiguration.advanced.binCount, 1024)
        XCTAssertEqual(FFTConfiguration.advanced.log2n, 11)
        XCTAssertEqual(
            FFTConfiguration.advanced.frequencyResolutionAt44_1kHz,
            44_100 / 2048,
            accuracy: 0.001
        )
    }

    func testHighSensitivitySelectsAdvanced() {
        XCTAssertEqual(FFTConfiguration.forHighSensitivityMode(false), .standard)
        XCTAssertEqual(FFTConfiguration.forHighSensitivityMode(true), .advanced)
    }
}

final class FFTAnalyzerConfigurationTests: XCTestCase {
    func testAnalyzerProducesExpectedBinCounts() {
        var samples = [Float](repeating: 0.02, count: 2048)
        let standardAnalyzer = FFTAnalyzer(sampleRate: 44_100, configuration: .standard)
        let advancedAnalyzer = FFTAnalyzer(sampleRate: 44_100, configuration: .advanced)

        let standard = samples.withUnsafeBufferPointer { ptr in
            standardAnalyzer.analyze(
                channelData: ptr.baseAddress!,
                frameLength: 1024,
                calibrationOffset: 0
            )
        }
        let advanced = samples.withUnsafeBufferPointer { ptr in
            advancedAnalyzer.analyze(
                channelData: ptr.baseAddress!,
                frameLength: 2048,
                calibrationOffset: 0
            )
        }

        XCTAssertEqual(standard?.decibels.count, 512)
        XCTAssertEqual(standard?.fftSize, 1024)
        XCTAssertEqual(advanced?.decibels.count, 1024)
        XCTAssertEqual(advanced?.fftSize, 2048)
    }

    func testReconfigureSwitchesActiveFFTSize() {
        let analyzer = FFTAnalyzer(sampleRate: 44_100, configuration: .standard)
        XCTAssertEqual(analyzer.activeFFTSize, 1024)
        analyzer.reconfigure(to: .advanced)
        XCTAssertEqual(analyzer.activeFFTSize, 2048)
    }
}
