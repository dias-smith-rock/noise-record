import AVFoundation
import CoreML
import SoundAnalysis

final class NoiseClassifierManager: NSObject, SNResultsObserving, @unchecked Sendable {
    var onClassification: ((String, Double) -> Void)?

    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "com.noiseapp.analysis")
    private var customModel: MLModel?

    func setup(format: AVAudioFormat, customModel: MLModel? = nil) {
        self.customModel = customModel ?? Self.loadBundledModel()
        analysisQueue.async { [weak self] in
            self?.buildPipeline(format: format)
        }
    }

    /// Loads `NoiseClassifier.mlmodelc` from the app bundle when present.
    private static func loadBundledModel() -> MLModel? {
        guard let url = Bundle.main.url(forResource: "NoiseClassifier", withExtension: "mlmodelc") else {
            return nil
        }
        return try? MLModel(contentsOf: url)
    }

    func append(buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        analysisQueue.async { [weak self] in
            self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }
    }

    func stop() {
        analysisQueue.async { [weak self] in
            self?.streamAnalyzer = nil
        }
    }

    private func buildPipeline(format: AVAudioFormat) {
        streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        do {
            let request: SNRequest
            if let model = customModel {
                let classifyRequest = try SNClassifySoundRequest(mlModel: model)
                classifyRequest.windowDuration = CMTime(seconds: 1.0, preferredTimescale: 600)
                classifyRequest.overlapFactor = 0.5
                request = classifyRequest
            } else {
                let classifyRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)
                classifyRequest.windowDuration = CMTime(seconds: 1.0, preferredTimescale: 600)
                classifyRequest.overlapFactor = 0.5
                request = classifyRequest
            }
            try streamAnalyzer?.add(request, withObserver: self)
        } catch {
            streamAnalyzer = nil
        }
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classification = result as? SNClassificationResult,
              let top = classification.classifications.first(where: { $0.confidence > 0.55 }) else { return }
        onClassification?(top.identifier, top.confidence)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {}

    func requestDidComplete(_ request: SNRequest) {}
}
