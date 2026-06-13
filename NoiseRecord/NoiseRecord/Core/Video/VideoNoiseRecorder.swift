import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import UIKit

enum VideoNoiseRecorderError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case writerSetupFailed(String)
    case notRecording
    case finishFailed(String)

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: L10n.errorVideoCameraUnavailable
        case .microphoneUnavailable: L10n.errorVideoMicUnavailable
        case .writerSetupFailed(let msg): L10n.errorVideoWriterSetupFailed(msg)
        case .notRecording: L10n.errorVideoNotRecording
        case .finishFailed(let msg): L10n.errorVideoFinishFailed(msg)
        }
    }
}

/// High-performance video evidence recorder with burned-in noise / time / GPS OSD.
final class VideoNoiseRecorder: NSObject, @unchecked Sendable {
    let dataBridge = NoiseDataBridge()

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.noiseapp.capture.session")
    private let videoQueue = DispatchQueue(label: "com.noiseapp.videoQueue")
    private let writerQueue = DispatchQueue(label: "com.noiseapp.writerQueue")

    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoDevice: AVCaptureDevice?
    private let maxUserZoomFactor: CGFloat = 5.0

    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var isSessionRunning = false
    private var isRecording = false
    private var sessionStarted = false
    private var outputURL: URL?
    private var pendingAudioSamples: [CMSampleBuffer] = []
    private var recordingOriginTime: CMTime?
    private var noiseTimelineSamples: [VideoNoiseSample] = []
    private var lastTimelineSampleTime: Double = -1
    private let timelineSampleInterval: TimeInterval = 0.1

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var onRecordingFinished: ((Result<URL, Error>) -> Void)?

    // MARK: - Session setup

    func configureSession() throws {
        var configError: Error?
        sessionQueue.sync {
            do {
                try self.setupCaptureSessionLocked()
            } catch {
                configError = error
            }
        }
        if let configError { throw configError }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isSessionRunning else { return }
            self.captureSession.startRunning()
            self.isSessionRunning = true
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.isSessionRunning else { return }
            if self.isRecording {
                self.stopRecordingInternal { _ in }
            }
            self.captureSession.stopRunning()
            self.isSessionRunning = false
        }
    }

    var captureSessionForPreview: AVCaptureSession { captureSession }

    var currentZoomFactor: CGFloat {
        sessionQueue.sync {
            videoDevice?.videoZoomFactor ?? 1.0
        }
    }

    var allowedZoomRange: ClosedRange<CGFloat> {
        sessionQueue.sync {
            guard let device = videoDevice else { return 1.0 ... 1.0 }
            let maxZoom = min(device.maxAvailableVideoZoomFactor, maxUserZoomFactor)
            return device.minAvailableVideoZoomFactor ... maxZoom
        }
    }

    func setZoomFactor(_ factor: CGFloat, completion: ((CGFloat) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let applied = self.applyZoomLocked(factor)
            if let completion {
                DispatchQueue.main.async {
                    completion(applied)
                }
            }
        }
    }

    private func applyZoomLocked(_ factor: CGFloat) -> CGFloat {
        guard let device = videoDevice else { return 1.0 }
        let maxZoom = min(device.maxAvailableVideoZoomFactor, maxUserZoomFactor)
        let clamped = max(device.minAvailableVideoZoomFactor, min(factor, maxZoom))
        do {
            try device.lockForConfiguration()
            if device.isRampingVideoZoom {
                device.cancelVideoZoomRamp()
            }
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            return clamped
        } catch {
            return device.videoZoomFactor
        }
    }

    private func setupCaptureSessionLocked() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        captureSession.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }
        videoDevice = device
        let videoInput = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(videoInput) else { throw VideoNoiseRecorderError.cameraUnavailable }
        captureSession.addInput(videoInput)

        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw VideoNoiseRecorderError.microphoneUnavailable
        }
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        guard captureSession.canAddInput(audioInput) else { throw VideoNoiseRecorderError.microphoneUnavailable }
        captureSession.addInput(audioInput)

        let videoOut = AVCaptureVideoDataOutput()
        videoOut.alwaysDiscardsLateVideoFrames = false
        videoOut.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        videoOut.setSampleBufferDelegate(self, queue: videoQueue)
        guard captureSession.canAddOutput(videoOut) else { throw VideoNoiseRecorderError.cameraUnavailable }
        captureSession.addOutput(videoOut)

        if let connection = videoOut.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        let audioOut = AVCaptureAudioDataOutput()
        audioOut.setSampleBufferDelegate(self, queue: writerQueue)
        guard captureSession.canAddOutput(audioOut) else { throw VideoNoiseRecorderError.microphoneUnavailable }
        captureSession.addOutput(audioOut)

        videoOutput = videoOut
    }

    // MARK: - Recording control

    static func makeOutputURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VideoEvidence", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return dir.appendingPathComponent("evidence_\(formatter.string(from: Date())).mp4")
    }

    func startRecording(to url: URL? = nil) {
        writerQueue.async { [weak self] in
            guard let self else { return }
            self.outputURL = url ?? Self.makeOutputURL()
            self.isRecording = true
            self.sessionStarted = false
            self.recordingOriginTime = nil
            self.noiseTimelineSamples.removeAll()
            self.lastTimelineSampleTime = -1
            self.pendingAudioSamples.removeAll()
            self.tearDownWriter()
        }
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        writerQueue.async { [weak self] in
            self?.stopRecordingInternal(completion: completion)
        }
    }

    private func stopRecordingInternal(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else {
            completion(.failure(VideoNoiseRecorderError.notRecording))
            return
        }
        isRecording = false

        guard sessionStarted, let writer = assetWriter, let url = outputURL else {
            tearDownWriter()
            completion(.failure(VideoNoiseRecorderError.notRecording))
            return
        }

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        writer.finishWriting { [weak self] in
            if let error = writer.error {
                completion(.failure(VideoNoiseRecorderError.finishFailed(error.localizedDescription)))
            } else {
                self?.saveNoiseTimeline(for: url)
                completion(.success(url))
            }
            self?.tearDownWriter()
        }
    }

    private func ensureWriter(for pixelBuffer: CVPixelBuffer) throws {
        guard assetWriter == nil, let url = outputURL else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44_100,
            AVEncoderBitRateKey: 96_000,
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
            throw VideoNoiseRecorderError.writerSetupFailed(L10n.errorVideoWriterAddTrackFailed)
        }
        writer.add(videoInput)
        writer.add(audioInput)
        guard writer.startWriting() else {
            throw VideoNoiseRecorderError.writerSetupFailed(writer.error?.localizedDescription ?? L10n.errorUnknown)
        }

        assetWriter = writer
        videoWriterInput = videoInput
        audioWriterInput = audioInput
        pixelBufferAdaptor = adaptor
    }

    private func tearDownWriter() {
        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        pixelBufferAdaptor = nil
        sessionStarted = false
        recordingOriginTime = nil
        noiseTimelineSamples.removeAll()
        lastTimelineSampleTime = -1
        pendingAudioSamples.removeAll()
    }

    private func saveNoiseTimeline(for videoURL: URL) {
        guard !noiseTimelineSamples.isEmpty else { return }
        let timeline = VideoNoiseTimeline(
            weighting: dataBridge.currentWeighting,
            samples: noiseTimelineSamples
        )
        try? VideoNoiseTimelineStore.save(timeline, for: videoURL)
    }

    private func appendTimelineSampleIfNeeded(at relativeTime: Double) {
        guard relativeTime >= 0 else { return }
        guard lastTimelineSampleTime < 0
            || relativeTime - lastTimelineSampleTime >= timelineSampleInterval else { return }
        noiseTimelineSamples.append(
            VideoNoiseSample(time: relativeTime, decibel: dataBridge.currentDecibel)
        )
        lastTimelineSampleTime = relativeTime
    }

    // MARK: - OSD rendering

    private func drawWatermark(on pixelBuffer: CVPixelBuffer, captureDate: Date) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let scale = max(CGFloat(width), CGFloat(height)) / 1920.0
        let cardWidth = min(600 * scale, CGFloat(width) - 80)
        let cardHeight = 180 * scale
        let margin: CGFloat = 40 * scale
        let cardRect = CGRect(x: margin, y: margin, width: cardWidth, height: cardHeight)

        UIGraphicsPushContext(context)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 16 * scale)
        UIColor.black.withAlphaComponent(0.6).setFill()
        cardPath.fill()

        let decibelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 42 * scale, weight: .bold),
            .foregroundColor: UIColor.systemOrange,
        ]
        dataBridge.overlayDecibelText.draw(
            at: CGPoint(x: cardRect.minX + 20 * scale, y: cardRect.minY + 18 * scale),
            withAttributes: decibelAttributes
        )

        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 22 * scale, weight: .regular),
            .foregroundColor: UIColor.white,
        ]
        let metaText = "\(timestampFormatter.string(from: captureDate))\n\(dataBridge.gpsString)"
        metaText.draw(
            at: CGPoint(x: cardRect.minX + 20 * scale, y: cardRect.minY + 78 * scale),
            withAttributes: metaAttributes
        )
        UIGraphicsPopContext()
        context.restoreGState()
    }

    private func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self, self.isRecording else { return }
            guard let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            do {
                if self.assetWriter == nil {
                    try self.ensureWriter(for: sourceBuffer)
                }
            } catch {
                self.isRecording = false
                return
            }

            guard let videoInput = self.videoWriterInput,
                  let adaptor = self.pixelBufferAdaptor,
                  videoInput.isReadyForMoreMediaData else { return }

            if !self.sessionStarted {
                self.assetWriter?.startSession(atSourceTime: timestamp)
                self.recordingOriginTime = timestamp
                self.sessionStarted = true
                self.flushPendingAudio()
            }

            if let origin = self.recordingOriginTime {
                let relative = CMTimeGetSeconds(CMTimeSubtract(timestamp, origin))
                self.appendTimelineSampleIfNeeded(at: relative)
            }

            guard let pool = adaptor.pixelBufferPool else { return }
            var outputBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputBuffer) == kCVReturnSuccess,
                  let outputBuffer else { return }

            CVPixelBufferLockBaseAddress(sourceBuffer, .readOnly)
            CVPixelBufferLockBaseAddress(outputBuffer, [])
            let rowCount = CVPixelBufferGetHeight(sourceBuffer)
            let copyBytes = min(
                CVPixelBufferGetBytesPerRow(sourceBuffer),
                CVPixelBufferGetBytesPerRow(outputBuffer)
            )
            if let src = CVPixelBufferGetBaseAddress(sourceBuffer),
               let dst = CVPixelBufferGetBaseAddress(outputBuffer) {
                for row in 0..<rowCount {
                    memcpy(dst.advanced(by: row * CVPixelBufferGetBytesPerRow(outputBuffer)),
                           src.advanced(by: row * CVPixelBufferGetBytesPerRow(sourceBuffer)),
                           copyBytes)
                }
            }
            CVPixelBufferUnlockBaseAddress(outputBuffer, [])
            CVPixelBufferUnlockBaseAddress(sourceBuffer, .readOnly)

            self.drawWatermark(on: outputBuffer, captureDate: Date())
            adaptor.append(outputBuffer, withPresentationTime: timestamp)
        }
    }

    private func processAudioSample(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self, self.isRecording else { return }
            guard let copy = self.copySampleBuffer(sampleBuffer) else { return }

            if !self.sessionStarted {
                self.pendingAudioSamples.append(copy)
                return
            }
            guard let audioInput = self.audioWriterInput, audioInput.isReadyForMoreMediaData else { return }
            audioInput.append(copy)
        }
    }

    private func flushPendingAudio() {
        guard let audioInput = audioWriterInput else { return }
        for buffer in pendingAudioSamples where audioInput.isReadyForMoreMediaData {
            audioInput.append(buffer)
        }
        pendingAudioSamples.removeAll()
    }

    private func copySampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        var copy: CMSampleBuffer?
        CMSampleBufferCreateCopy(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleBufferOut: &copy)
        return copy
    }
}

// MARK: - AVCapture delegates

extension VideoNoiseRecorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output is AVCaptureVideoDataOutput {
            processVideoSample(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            processAudioSample(sampleBuffer)
        }
    }
}
