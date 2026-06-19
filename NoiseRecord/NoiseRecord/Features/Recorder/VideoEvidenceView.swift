import AVFoundation
import AVKit
import CoreLocation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class VideoEvidenceCoordinator {
    let recorder = VideoNoiseRecorder()
    let locationProvider = LocationEvidenceProvider()

    var isRecording = false
    var isSessionReady = false
    var isPreviewReady = false
    var errorMessage: String?
    var recordingStartedAt: Date?
    var peakDB: Float = 0
    var sessionPeakDB: Float = 0
    var cameraPosition: AVCaptureDevice.Position = .back
    var isDualCameraEnabled = false
    var isMultiCamSupported = false
    var previewDetachGeneration = 0

    func configure(backgroundMonitoringEnabled: Bool, isMonitoring: Bool) async {
        let configureSignpost = VideoTabPerformance.begin(.configureTotal)
        defer { VideoTabPerformance.end(.configureTotal, configureSignpost) }

        isSessionReady = false
        isPreviewReady = false
        isMultiCamSupported = VideoNoiseRecorder.isMultiCamSupported

        do {
            let audioSignpost = VideoTabPerformance.begin(.audioSession)
            try configureAudioSessionForVideo(
                backgroundMonitoringEnabled: backgroundMonitoringEnabled,
                isMonitoring: isMonitoring
            )
            VideoTabPerformance.end(.audioSession, audioSignpost)
            VideoTabPerformance.mark(.audioSessionDone)

            let captureSignpost = VideoTabPerformance.begin(.captureConfigure)
            try await recorder.configureSession()
            VideoTabPerformance.end(.captureConfigure, captureSignpost)
            VideoTabPerformance.mark(.captureConfigureDone)

            VideoTabPerformance.mark(.captureStartRequested)
            recorder.startSession { [weak self] position in
                guard let self else { return }
                self.cameraPosition = position
                self.isPreviewReady = true
                VideoTabPerformance.mark(.previewReady)
            }

            locationProvider.requestPermission()
            VideoTabPerformance.mark(.locationPermissionRequested)
            isSessionReady = true
            VideoTabPerformance.mark(.uiReady)
            VideoTabPerformance.mark(.configureComplete)
        } catch {
            VideoTabPerformance.mark(.configureFailed)
            errorMessage = error.localizedDescription
        }
    }

    func syncNoise(from engine: NoiseMonitorEngine) {
        let weighting = engine.effectiveWeighting.rawValue
        recorder.dataBridge.update(decibel: engine.currentDB, weighting: weighting)
        if engine.currentDB > sessionPeakDB {
            sessionPeakDB = engine.currentDB
        }
        if isRecording, engine.currentDB > peakDB {
            peakDB = engine.currentDB
        }
    }

    func syncLocation() {
        recorder.dataBridge.updateGPS(
            latitude: locationProvider.latitude,
            longitude: locationProvider.longitude
        )
    }

    func startRecording() async throws {
        guard isSessionReady, isPreviewReady, !isRecording else { return }
        peakDB = 0
        recordingStartedAt = Date()
        locationProvider.startUpdating()
        try await recorder.startRecording()
        isRecording = true
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else { return }
        isRecording = false
        locationProvider.stopUpdating()
        recorder.stopRecording(completion: completion)
    }

    func teardown() {
        let teardownSignpost = VideoTabPerformance.begin(.teardown)
        locationProvider.stopUpdating()
        isSessionReady = false
        isPreviewReady = false
        previewDetachGeneration += 1
        DispatchQueue.main.async { [weak self] in
            self?.recorder.pausePreview()
        }
        VideoTabPerformance.end(.teardown, teardownSignpost)
        VideoTabPerformance.mark(.teardownDone)
    }

    func switchCamera() {
        guard isSessionReady, !isRecording, !isDualCameraEnabled else { return }
        recorder.switchCamera { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let position):
                self.cameraPosition = position
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func setDualCameraEnabled(_ enabled: Bool) {
        guard isSessionReady, !isRecording else { return }
        if enabled, !isMultiCamSupported {
            errorMessage = L10n.errorVideoDualCameraUnsupported
            return
        }

        isPreviewReady = false
        previewDetachGeneration += 1

        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.recorder.setDualCameraEnabled(enabled) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.isDualCameraEnabled = enabled
                        self.cameraPosition = .back
                        self.isPreviewReady = true
                    case .failure(let error):
                        self.isDualCameraEnabled = false
                        self.errorMessage = error.localizedDescription
                        self.isPreviewReady = true
                    }
                }
            }
        }
    }

    private func configureAudioSessionForVideo(
        backgroundMonitoringEnabled: Bool,
        isMonitoring: Bool
    ) throws {
        if isMonitoring {
            try BackgroundAudioSession.activateForMeasurement(
                backgroundEnabled: backgroundMonitoringEnabled
            )
        } else {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true)
        }
    }
}

struct VideoEvidenceView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Bindable var coordinator: VideoEvidenceCoordinator
    let isTabActive: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var player: AVPlayer?
    @State private var isPreparingRecording = false
    @State private var savedVideoURL: URL?
    @State private var presentedVideoURL: URL?
    @State private var presentedVideoTitle: String?
    @State private var previewZoomFactor: CGFloat = 1.0
    @State private var showCameraPermissionDenied = false
    @State private var showLocationPermissionDenied = false
    @State private var didPromptLocationDenied = false
    @State private var lastNoiseSync = Date.distantPast

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: L10n.videoTitle, theme: theme)

            ScrollView {
                VStack(spacing: 20) {
                    previewSection
                    controlSection
                    tipsSection
                }
                .padding()
            }
        }
        .observesAppLanguage()
        .onAppear {
            VideoTabPerformance.mark(.viewAppear)
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .task(id: isTabActive) {
            if isTabActive {
                VideoTabPerformance.mark(.taskActiveBegin)
                await coordinator.configure(
                    backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
                    isMonitoring: engine.isMonitoring
                )
                engine.refreshCalibrationOffset()
                lastNoiseSync = .distantPast
                coordinator.syncNoise(from: engine)
                VideoTabPerformance.mark(.syncNoiseDone)
                engine.restoreMonitoringAfterExternalSession()
                VideoTabPerformance.mark(.restoreMonitoringDone)
                VideoTabPerformance.mark(.taskActiveComplete)
            } else {
                VideoTabPerformance.mark(.taskInactiveBegin)
                coordinator.teardown()
                engine.restoreMonitoringAfterExternalSession()
                VideoTabPerformance.mark(.taskInactiveComplete)
            }
        }
        .onChange(of: engine.currentDB) { _, _ in
            guard isTabActive else { return }
            let now = Date()
            let interval = coordinator.isRecording ? 0.1 : 0.25
            guard now.timeIntervalSince(lastNoiseSync) >= interval else { return }
            lastNoiseSync = now
            coordinator.syncNoise(from: engine)
        }
        .onReceive(NotificationCenter.default.publisher(for: DeviceCalibrationStore.didChangeNotification)) { _ in
            guard isTabActive else { return }
            engine.refreshCalibrationOffset()
            coordinator.syncNoise(from: engine)
        }
        .onChange(of: coordinator.locationProvider.latitude) { _, _ in
            coordinator.syncLocation()
        }
        .alert(L10n.errorTitle, isPresented: .constant(coordinator.errorMessage != nil)) {
            Button(L10n.ok) { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
        .permissionDeniedAlert(
            isPresented: $showCameraPermissionDenied,
            title: L10n.permissionCameraDeniedTitle,
            message: L10n.permissionCameraDeniedMessage
        )
        .permissionDeniedAlert(
            isPresented: $showLocationPermissionDenied,
            title: L10n.permissionLocationDeniedTitle,
            message: L10n.permissionLocationDeniedMessage
        )
        .onChange(of: coordinator.errorMessage) { _, message in
            guard let message else { return }
            if message.localizedCaseInsensitiveContains("camera") {
                showCameraPermissionDenied = true
            }
        }
        .onChange(of: coordinator.locationProvider.authorizationStatus) { _, status in
            guard !didPromptLocationDenied else { return }
            if status == .denied || status == .restricted {
                didPromptLocationDenied = true
                showLocationPermissionDenied = true
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { presentedVideoURL != nil },
            set: { if !$0 { presentedVideoURL = nil; presentedVideoTitle = nil } }
        )) {
            if let url = presentedVideoURL {
                SyncedVideoPlayerView(
                    url: url,
                    title: presentedVideoTitle ?? url.lastPathComponent,
                    coexistingWithMonitoring: engine.isMonitoring,
                    backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
                    onDismiss: {
                        presentedVideoURL = nil
                        presentedVideoTitle = nil
                        engine.restoreMonitoringAfterExternalSession()
                    }
                )
            }
        }
    }

    private var previewSection: some View {
        ZStack(alignment: .bottomLeading) {
            CameraPreviewView(
                session: coordinator.recorder.captureSessionForPreview,
                isDualCamera: coordinator.isDualCameraEnabled,
                backPreviewPort: coordinator.recorder.backPreviewVideoPort,
                frontPreviewPort: coordinator.recorder.frontPreviewVideoPort,
                isPreviewActive: coordinator.isPreviewReady,
                detachGeneration: coordinator.previewDetachGeneration,
                isFrontCamera: { coordinator.cameraPosition == .front },
                zoomGesturesEnabled: !coordinator.isDualCameraEnabled,
                currentZoom: { previewZoomFactor },
                onZoomChange: { factor in
                    coordinator.recorder.setZoomFactor(factor) { applied in
                        previewZoomFactor = applied
                    }
                }
            )
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.surfaceBorder, lineWidth: 1)
            )
            .overlay {
                if coordinator.isSessionReady, !coordinator.isPreviewReady {
                    ZStack {
                        Color.black.opacity(0.35)
                        ProgressView()
                            .tint(.white)
                    }
                }
            }

            if previewZoomFactor > 1.05, !coordinator.isDualCameraEnabled {
                Text(String(format: "%.1fx", previewZoomFactor))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)
            }

            HStack(spacing: 10) {
                if !coordinator.isDualCameraEnabled {
                    Button {
                        coordinator.switchCamera()
                        previewZoomFactor = 1.0
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L10n.videoSwitchCamera)
                    .disabled(!coordinator.isSessionReady || !coordinator.isPreviewReady || coordinator.isRecording)
                }

                Button {
                    coordinator.setDualCameraEnabled(!coordinator.isDualCameraEnabled)
                    previewZoomFactor = 1.0
                } label: {
                    Image(systemName: coordinator.isDualCameraEnabled ? "camera.on.rectangle.fill" : "camera.on.rectangle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(coordinator.isDualCameraEnabled ? theme.accent : .white)
                        .padding(10)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .accessibilityLabel(L10n.videoDualCamera)
                .disabled(
                    !coordinator.isSessionReady
                        || !coordinator.isPreviewReady
                        || coordinator.isRecording
                        || !coordinator.isMultiCamSupported
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if coordinator.isRecording {
                HStack(spacing: 8) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text(L10n.videoRecBadge)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.overlayTimeLabel)
                    .font(.caption.bold())
                    .foregroundStyle(theme.accent)
                Text(Date().formatted(date: .numeric, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(10)
            .background(.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .allowsHitTesting(false)
        }
    }

    private var controlSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProMetricCard(
                    title: L10n.videoCurrentDb,
                    value: String(format: "%.1f %@", engine.currentDB, engine.effectiveWeighting.rawValue),
                    theme: theme
                )
                ProMetricCard(title: L10n.videoClipPeak, value: String(format: "%.0f", coordinator.peakDB), theme: theme)
                ProMetricCard(
                    title: L10n.videoGPS,
                    value: coordinator.locationProvider.latitude != nil ? L10n.videoGpsLocated : L10n.videoGpsPending,
                    theme: theme
                )
            }

            if !engine.isMonitoring || !engine.isHighSensitivityMode {
                Text(L10n.videoAutoMonitoringHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let savedVideoURL {
                VStack(spacing: 8) {
                    Label(L10n.videoSaved(savedVideoURL.lastPathComponent), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                        .multilineTextAlignment(.center)
                    Button(L10n.videoPreviewRecording) {
                        presentedVideoURL = savedVideoURL
                        presentedVideoTitle = savedVideoURL.lastPathComponent
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button {
                if coordinator.isRecording {
                    coordinator.stopRecording { result in
                        Task { @MainActor in
                            handleRecordingFinished(result)
                        }
                    }
                } else {
                    Task { await startEvidenceRecording() }
                }
            } label: {
                Label(
                    coordinator.isRecording ? L10n.videoStopAndSave : L10n.videoStartRecording,
                    systemImage: coordinator.isRecording ? "stop.circle.fill" : "video.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(coordinator.isRecording ? .red : theme.accent)
            .disabled(!coordinator.isSessionReady || !coordinator.isPreviewReady || isPreparingRecording)
        }
    }

    private var tipsSection: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.videoWatermarkTitle, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.accent)
                Text(L10n.videoWatermarkBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startEvidenceRecording() async {
        guard coordinator.isSessionReady, coordinator.isPreviewReady, !coordinator.isRecording else { return }
        isPreparingRecording = true
        savedVideoURL = nil
        defer { isPreparingRecording = false }

        let ready = await engine.ensureMonitoringForVideoEvidence()
        guard ready else {
            coordinator.errorMessage = engine.errorMessage ?? L10n.videoMonitoringStartFailed
            return
        }

        coordinator.syncNoise(from: engine)
        coordinator.syncLocation()
        do {
            try await coordinator.startRecording()
            AppTelemetry.logVideoRecordingStart()
        } catch {
            coordinator.errorMessage = error.localizedDescription
        }
    }

    private func handleRecordingFinished(_ result: Result<URL, Error>) {
        engine.endTemporaryHighSensitivityForVideoIfNeeded()
        engine.restoreMonitoringAfterExternalSession()
        switch result {
        case .success(let url):
            let started = coordinator.recordingStartedAt ?? Date()
            let session = VideoEvidenceSession(
                fileName: url.lastPathComponent,
                filePath: EvidenceFileResolver.makeRelativePath(from: url),
                startedAt: started,
                endedAt: Date(),
                peakDB: coordinator.peakDB,
                averageDB: engine.averageDB,
                latitude: coordinator.locationProvider.latitude,
                longitude: coordinator.locationProvider.longitude
            )
            modelContext.insert(session)
            try? modelContext.save()
            savedVideoURL = url
            AppReviewStore.noteEvidenceFileSaved()
        case .failure(let error):
            coordinator.errorMessage = error.localizedDescription
        }
    }
}
