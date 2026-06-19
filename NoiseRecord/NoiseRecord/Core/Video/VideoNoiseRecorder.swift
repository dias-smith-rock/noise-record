import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import UIKit

enum VideoNoiseRecorderError: LocalizedError {
    case cameraUnavailable
    case cannotSwitchCameraWhileRecording
    case cannotToggleDualCameraWhileRecording
    case dualCameraUnsupported
    case microphoneUnavailable
    case writerSetupFailed(String)
    case notRecording
    case finishFailed(String)
    case sessionNotRunning

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: L10n.errorVideoCameraUnavailable
        case .cannotSwitchCameraWhileRecording: L10n.errorVideoCannotSwitchCameraWhileRecording
        case .cannotToggleDualCameraWhileRecording: L10n.errorVideoCannotToggleDualCameraWhileRecording
        case .dualCameraUnsupported: L10n.errorVideoDualCameraUnsupported
        case .microphoneUnavailable: L10n.errorVideoMicUnavailable
        case .writerSetupFailed(let msg): L10n.errorVideoWriterSetupFailed(msg)
        case .notRecording: L10n.errorVideoNotRecording
        case .finishFailed(let msg): L10n.errorVideoFinishFailed(msg)
        case .sessionNotRunning: L10n.errorVideoCameraUnavailable
        }
    }
}

/// High-performance video evidence recorder with burned-in noise / time / GPS OSD.
final class VideoNoiseRecorder: NSObject, @unchecked Sendable {
    let dataBridge = NoiseDataBridge()

    private var captureSession: AVCaptureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.noiseapp.capture.session")
    private let videoQueue = DispatchQueue(label: "com.noiseapp.videoQueue")
    private let writerQueue = DispatchQueue(label: "com.noiseapp.writerQueue")

    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var videoDevice: AVCaptureDevice?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private let maxUserZoomFactor: CGFloat = 5.0

    private var backVideoInput: AVCaptureDeviceInput?
    private var frontVideoInput: AVCaptureDeviceInput?
    private var backVideoDevice: AVCaptureDevice?
    private var frontVideoDevice: AVCaptureDevice?
    private var backVideoOutput: AVCaptureVideoDataOutput?
    private var frontVideoOutput: AVCaptureVideoDataOutput?
    private(set) var backPreviewVideoPort: AVCaptureInput.Port?
    private(set) var frontPreviewVideoPort: AVCaptureInput.Port?
    private(set) var isDualCameraEnabled = false

    private var latestFrontSampleBuffer: CMSampleBuffer?
    private var latestFrontTimestamp = CMTime.invalid
    private let frontFrameMaxAge: Double = 0.05

    private var isPreviewConfigured = false
    private var recordingOutputsAttached = false

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
    private var cachedMetaText = ""
    private var lastMetaRefreshTime: CFAbsoluteTime = 0
    private let metaRefreshInterval: CFAbsoluteTime = 0.5

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var onRecordingFinished: ((Result<URL, Error>) -> Void)?

    static var isMultiCamSupported: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }

    // MARK: - Session setup

    func configureSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: VideoNoiseRecorderError.cameraUnavailable)
                    return
                }
                do {
                    if !self.isPreviewConfigured {
                        try self.setupSingleCamPreviewSessionLocked(position: .back)
                        self.isPreviewConfigured = true
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func startSession(completion: ((AVCaptureDevice.Position) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isSessionRunning {
                self.captureSession.startRunning()
                self.isSessionRunning = true
                VideoTabPerformance.mark(.captureSessionRunning)
            }
            let position = self.currentCameraPosition
            if let completion {
                DispatchQueue.main.async {
                    completion(position)
                }
            }
        }
    }

    /// Stops preview capture but keeps the configured preview pipeline for fast re-entry.
    func pausePreview() {
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

    func setDualCameraEnabled(_ enabled: Bool, completion: ((Result<Void, Error>) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard enabled != self.isDualCameraEnabled else {
                DispatchQueue.main.async { completion?(.success(())) }
                return
            }
            guard !self.isRecording else {
                DispatchQueue.main.async {
                    completion?(.failure(VideoNoiseRecorderError.cannotToggleDualCameraWhileRecording))
                }
                return
            }
            if enabled, !Self.isMultiCamSupported {
                DispatchQueue.main.async {
                    completion?(.failure(VideoNoiseRecorderError.dualCameraUnsupported))
                }
                return
            }

            let wasRunning = self.isSessionRunning
            if wasRunning {
                self.captureSession.stopRunning()
                self.isSessionRunning = false
            }

            do {
                if enabled {
                    try self.setupMultiCamPreviewSessionLocked()
                } else {
                    self.captureSession = AVCaptureSession()
                    try self.setupSingleCamPreviewSessionLocked(position: .back)
                }
                self.isPreviewConfigured = true
                if wasRunning {
                    self.captureSession.startRunning()
                    self.isSessionRunning = true
                }
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }

    func setZoomFactor(_ factor: CGFloat, completion: ((CGFloat) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isDualCameraEnabled else {
                if let completion {
                    DispatchQueue.main.async { completion(1.0) }
                }
                return
            }
            let applied = self.applyZoomLocked(factor)
            if let completion {
                DispatchQueue.main.async {
                    completion(applied)
                }
            }
        }
    }

    func switchCamera(completion: ((Result<AVCaptureDevice.Position, Error>) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isDualCameraEnabled else {
                DispatchQueue.main.async {
                    completion?(.failure(VideoNoiseRecorderError.cannotSwitchCameraWhileRecording))
                }
                return
            }
            guard !self.isRecording else {
                DispatchQueue.main.async {
                    completion?(.failure(VideoNoiseRecorderError.cannotSwitchCameraWhileRecording))
                }
                return
            }

            let newPosition: AVCaptureDevice.Position = self.currentCameraPosition == .back ? .front : .back
            do {
                self.captureSession.beginConfiguration()
                defer { self.captureSession.commitConfiguration() }

                if let videoInput = self.videoInput {
                    self.captureSession.removeInput(videoInput)
                }
                try self.addVideoInputLocked(position: newPosition)
                _ = self.applyZoomLocked(1.0)
                self.configureSingleVideoConnectionLocked()

                DispatchQueue.main.async {
                    completion?(.success(newPosition))
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(.failure(error))
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

    private func setupSingleCamPreviewSessionLocked(position: AVCaptureDevice.Position) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        captureSession.sessionPreset = .high
        try addVideoInputLocked(position: position)

        clearDualCameraStateLocked()
        videoOutput = nil
        audioInput = nil
        audioOutput = nil
        recordingOutputsAttached = false
        isDualCameraEnabled = false
    }

    private func setupMultiCamPreviewSessionLocked() throws {
        guard Self.isMultiCamSupported else {
            throw VideoNoiseRecorderError.dualCameraUnsupported
        }
        guard let backDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }

        let multiSession = AVCaptureMultiCamSession()
        multiSession.beginConfiguration()
        defer { multiSession.commitConfiguration() }

        let backInput = try AVCaptureDeviceInput(device: backDevice)
        let frontInput = try AVCaptureDeviceInput(device: frontDevice)
        guard multiSession.canAddInput(backInput), multiSession.canAddInput(frontInput) else {
            throw VideoNoiseRecorderError.dualCameraUnsupported
        }

        multiSession.addInputWithNoConnections(backInput)
        multiSession.addInputWithNoConnections(frontInput)

        let backPort = backInput.ports(
            for: .video,
            sourceDeviceType: backDevice.deviceType,
            sourceDevicePosition: .back
        ).first
        let frontPort = frontInput.ports(
            for: .video,
            sourceDeviceType: frontDevice.deviceType,
            sourceDevicePosition: .front
        ).first
        guard backPort != nil, frontPort != nil else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }

        captureSession = multiSession
        backVideoInput = backInput
        frontVideoInput = frontInput
        backVideoDevice = backDevice
        frontVideoDevice = frontDevice
        videoDevice = backDevice
        currentCameraPosition = .back
        backPreviewVideoPort = backPort
        frontPreviewVideoPort = frontPort

        videoInput = nil
        videoOutput = nil
        backVideoOutput = nil
        frontVideoOutput = nil
        audioInput = nil
        audioOutput = nil
        recordingOutputsAttached = false
        isDualCameraEnabled = true
    }

    private func clearDualCameraStateLocked() {
        backVideoInput = nil
        frontVideoInput = nil
        backVideoDevice = nil
        frontVideoDevice = nil
        backVideoOutput = nil
        frontVideoOutput = nil
        backPreviewVideoPort = nil
        frontPreviewVideoPort = nil
        clearFrontFrameCacheLocked()
    }

    private func clearFrontFrameCacheLocked() {
        latestFrontSampleBuffer = nil
        latestFrontTimestamp = .invalid
    }

    private func addVideoInputLocked(position: AVCaptureDevice.Position) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else { throw VideoNoiseRecorderError.cameraUnavailable }
        captureSession.addInput(input)
        videoInput = input
        videoDevice = device
        currentCameraPosition = position
    }

    private func attachRecordingOutputsLocked() throws {
        guard !recordingOutputsAttached else { return }
        if isDualCameraEnabled {
            try attachDualRecordingOutputsLocked()
        } else {
            try attachSingleRecordingOutputsLocked()
        }
    }

    private func attachSingleRecordingOutputsLocked() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        }

        let videoOut = AVCaptureVideoDataOutput()
        videoOut.alwaysDiscardsLateVideoFrames = true
        videoOut.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        videoOut.setSampleBufferDelegate(self, queue: videoQueue)
        guard captureSession.canAddOutput(videoOut) else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }
        captureSession.addOutput(videoOut)
        videoOutput = videoOut
        configureSingleVideoConnectionLocked()
        recordingOutputsAttached = true
    }

    private func attachDualRecordingOutputsLocked() throws {
        guard let multiSession = captureSession as? AVCaptureMultiCamSession,
              let backPort = backPreviewVideoPort,
              let frontPort = frontPreviewVideoPort else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }

        multiSession.beginConfiguration()
        defer { multiSession.commitConfiguration() }

        let backOut = AVCaptureVideoDataOutput()
        backOut.alwaysDiscardsLateVideoFrames = true
        backOut.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        backOut.setSampleBufferDelegate(self, queue: videoQueue)

        let frontOut = AVCaptureVideoDataOutput()
        frontOut.alwaysDiscardsLateVideoFrames = true
        frontOut.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        frontOut.setSampleBufferDelegate(self, queue: videoQueue)

        guard multiSession.canAddOutput(backOut), multiSession.canAddOutput(frontOut) else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }

        multiSession.addOutputWithNoConnections(backOut)
        multiSession.addOutputWithNoConnections(frontOut)

        let backConnection = AVCaptureConnection(inputPorts: [backPort], output: backOut)
        let frontConnection = AVCaptureConnection(inputPorts: [frontPort], output: frontOut)
        guard multiSession.canAddConnection(backConnection),
              multiSession.canAddConnection(frontConnection) else {
            throw VideoNoiseRecorderError.cameraUnavailable
        }

        if backConnection.isVideoRotationAngleSupported(90) {
            backConnection.videoRotationAngle = 90
        }
        if frontConnection.isVideoRotationAngleSupported(90) {
            frontConnection.videoRotationAngle = 90
        }
        if frontConnection.isVideoMirroringSupported {
            frontConnection.automaticallyAdjustsVideoMirroring = false
            frontConnection.isVideoMirrored = true
        }

        multiSession.addConnection(backConnection)
        multiSession.addConnection(frontConnection)

        backVideoOutput = backOut
        frontVideoOutput = frontOut
        videoOutput = backOut
        recordingOutputsAttached = true
    }

    private func detachRecordingOutputsLocked() {
        guard recordingOutputsAttached else { return }

        captureSession.beginConfiguration()
        if let backVideoOutput {
            captureSession.removeOutput(backVideoOutput)
        }
        if let frontVideoOutput, frontVideoOutput !== backVideoOutput {
            captureSession.removeOutput(frontVideoOutput)
        }
        if !isDualCameraEnabled, captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        captureSession.commitConfiguration()

        backVideoOutput = nil
        frontVideoOutput = nil
        videoOutput = nil
        recordingOutputsAttached = false
        clearFrontFrameCacheLocked()
    }

    private func configureSingleVideoConnectionLocked() {
        guard let connection = videoOutput?.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = currentCameraPosition == .front
        }
    }

    private func attachAudioCaptureLocked() throws {
        guard audioInput == nil else { return }

        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw VideoNoiseRecorderError.microphoneUnavailable
        }
        let input = try AVCaptureDeviceInput(device: audioDevice)
        guard captureSession.canAddInput(input) else {
            throw VideoNoiseRecorderError.microphoneUnavailable
        }

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: writerQueue)
        guard captureSession.canAddOutput(output) else {
            throw VideoNoiseRecorderError.microphoneUnavailable
        }

        captureSession.beginConfiguration()
        captureSession.addInput(input)
        captureSession.addOutput(output)
        captureSession.commitConfiguration()

        audioInput = input
        audioOutput = output
    }

    private func detachAudioCaptureLocked() {
        guard audioInput != nil || audioOutput != nil else { return }

        captureSession.beginConfiguration()
        if let audioOutput {
            captureSession.removeOutput(audioOutput)
        }
        if let audioInput {
            captureSession.removeInput(audioInput)
        }
        captureSession.commitConfiguration()

        audioInput = nil
        audioOutput = nil
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

    func startRecording(to url: URL? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: VideoNoiseRecorderError.notRecording)
                    return
                }
                guard self.isSessionRunning else {
                    continuation.resume(throwing: VideoNoiseRecorderError.sessionNotRunning)
                    return
                }
                do {
                    try self.attachRecordingOutputsLocked()
                    try self.attachAudioCaptureLocked()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                self.writerQueue.async {
                    self.outputURL = url ?? Self.makeOutputURL()
                    self.isRecording = true
                    self.sessionStarted = false
                    self.recordingOriginTime = nil
                    self.noiseTimelineSamples.removeAll()
                    self.lastTimelineSampleTime = -1
                    self.pendingAudioSamples.removeAll()
                    self.clearFrontFrameCacheLocked()
                    self.tearDownWriter()
                    continuation.resume()
                }
            }
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
            clearFrontFrameCacheLocked()
            sessionQueue.async { [weak self] in
                self?.detachAudioCaptureLocked()
                self?.detachRecordingOutputsLocked()
            }
            completion(.failure(VideoNoiseRecorderError.notRecording))
            return
        }

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        writer.finishWriting { [weak self] in
            guard let self else { return }
            if let error = writer.error {
                completion(.failure(VideoNoiseRecorderError.finishFailed(error.localizedDescription)))
            } else {
                self.saveNoiseTimeline(for: url)
                completion(.success(url))
            }
            self.tearDownWriter()
            self.clearFrontFrameCacheLocked()
            self.sessionQueue.async {
                self.detachAudioCaptureLocked()
                self.detachRecordingOutputsLocked()
            }
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
        let signpost = PerformanceSignpost.begin(.drawWatermark)
        defer { PerformanceSignpost.end(.drawWatermark, signpost) }

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
        let cardRect = CGRect(
            x: CGFloat(width) - margin - cardWidth,
            y: CGFloat(height) - margin - cardHeight,
            width: cardWidth,
            height: cardHeight
        )

        UIGraphicsPushContext(context)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 16 * scale)
        UIColor.black.withAlphaComponent(0.6).setFill()
        cardPath.fill()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 42 * scale, weight: .bold),
            .foregroundColor: UIColor.systemOrange,
        ]
        dataBridge.overlayTimeAndLocationTitle.draw(
            at: CGPoint(x: cardRect.minX + 20 * scale, y: cardRect.minY + 18 * scale),
            withAttributes: titleAttributes
        )

        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 22 * scale, weight: .regular),
            .foregroundColor: UIColor.white,
        ]
        let metaText = refreshedMetaText(captureDate: captureDate)
        metaText.draw(
            at: CGPoint(x: cardRect.minX + 20 * scale, y: cardRect.minY + 78 * scale),
            withAttributes: metaAttributes
        )
        UIGraphicsPopContext()
        context.restoreGState()
    }

    private func refreshedMetaText(captureDate: Date) -> String {
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastMetaRefreshTime >= metaRefreshInterval || cachedMetaText.isEmpty {
            lastMetaRefreshTime = now
            cachedMetaText = """
            \(timestampFormatter.string(from: captureDate))
            \(dataBridge.gpsString)
            \(dataBridge.overlayDecibelText)
            """
        }
        return cachedMetaText
    }

    private func processFrontVideoSample(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self, self.isRecording, self.isDualCameraEnabled else { return }
            self.latestFrontSampleBuffer = self.copySampleBuffer(sampleBuffer)
            self.latestFrontTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }
    }

    private func processBackVideoSample(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            let signpost = PerformanceSignpost.begin(.processVideoSample)
            defer { PerformanceSignpost.end(.processVideoSample, signpost) }

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

            if self.isDualCameraEnabled,
               let frontSample = self.latestFrontSampleBuffer,
               let frontBuffer = CMSampleBufferGetImageBuffer(frontSample),
               self.latestFrontTimestamp.isValid,
               abs(CMTimeGetSeconds(CMTimeSubtract(timestamp, self.latestFrontTimestamp))) <= self.frontFrameMaxAge {
                DualCameraCompositor.composite(back: sourceBuffer, front: frontBuffer, into: outputBuffer)
            } else {
                self.copyPixelBuffer(from: sourceBuffer, to: outputBuffer)
            }

            self.drawWatermark(on: outputBuffer, captureDate: Date())
            adaptor.append(outputBuffer, withPresentationTime: timestamp)
        }
    }

    private func copyPixelBuffer(from source: CVPixelBuffer, to destination: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(destination, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }

        let rowCount = CVPixelBufferGetHeight(source)
        let copyBytes = min(
            CVPixelBufferGetBytesPerRow(source),
            CVPixelBufferGetBytesPerRow(destination)
        )
        guard let src = CVPixelBufferGetBaseAddress(source),
              let dst = CVPixelBufferGetBaseAddress(destination) else { return }

        for row in 0..<rowCount {
            memcpy(
                dst.advanced(by: row * CVPixelBufferGetBytesPerRow(destination)),
                src.advanced(by: row * CVPixelBufferGetBytesPerRow(source)),
                copyBytes
            )
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
        if let frontVideoOutput, output === frontVideoOutput {
            processFrontVideoSample(sampleBuffer)
        } else if output is AVCaptureVideoDataOutput {
            processBackVideoSample(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            processAudioSample(sampleBuffer)
        }
    }
}
