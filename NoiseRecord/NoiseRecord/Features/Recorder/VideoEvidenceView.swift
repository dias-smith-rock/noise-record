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

    private(set) var isRecording = false
    var isSessionReady = false
    var isPreviewReady = false
    var errorMessage: String?
    var recordingStartedAt: Date?
    var peakDB: Float = 0
    var sessionPeakDB: Float = 0
    var cameraPosition: AVCaptureDevice.Position = .back
    var currentSegmentGroupID: UUID?

    var onSegmentFinished: ((VideoSegmentFinishedEvent) -> Void)?

    func configure(backgroundMonitoringEnabled: Bool, isMonitoring: Bool) async {
        let configureSignpost = VideoTabPerformance.begin(.configureTotal)
        defer { VideoTabPerformance.end(.configureTotal, configureSignpost) }

        isSessionReady = false
        isPreviewReady = false

        do {
            let audioSignpost = VideoTabPerformance.begin(.audioSession)
            try configureAudioSessionForVideo(
                backgroundMonitoringEnabled: backgroundMonitoringEnabled,
                isMonitoring: isMonitoring
            )
            VideoTabPerformance.end(.audioSession, audioSignpost)
            VideoTabPerformance.mark(.audioSessionDone)

            let captureSignpost = VideoTabPerformance.begin(.captureConfigure)
            try await recorder.configureSession(
                backgroundMonitoringEnabled: backgroundMonitoringEnabled
            )
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
            installRecorderCallbacks()
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
        // AVAudioEngine monitoring tap — sole source for burned-in watermark dB.
        recorder.dataBridge.update(decibel: engine.currentDB, weighting: weighting)
        if engine.currentDB > sessionPeakDB {
            sessionPeakDB = engine.currentDB
        }
        if isRecording, engine.currentDB > peakDB {
            peakDB = engine.currentDB
        }
    }

    func syncLocation(from engine: NoiseMonitorEngine? = nil) {
        let coordinates = resolvedCoordinates(from: engine)
        recorder.dataBridge.updateGPS(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
    }

    func resolvedCoordinates(from engine: NoiseMonitorEngine? = nil) -> (latitude: Double?, longitude: Double?) {
        (
            locationProvider.latitude ?? engine?.evidenceLatitude,
            locationProvider.longitude ?? engine?.evidenceLongitude
        )
    }

    func startRecording() async throws {
        let isPremium = SubscriptionManager.shared.isPremiumUser
        guard isPremium || FreemiumUsageStore.shared.canStartVideoRecording(isPremium: isPremium) else {
            AppTelemetry.logProductEvent(
                "freemium_limit_hit",
                parameters: ["limit_type": "video_daily"]
            )
            PaywallPresenter.shared.present(context: .videoDailyLimit)
            return
        }
        guard isSessionReady, isPreviewReady, !isRecording else { return }
        peakDB = 0
        recordingStartedAt = Date()
        currentSegmentGroupID = nil
        locationProvider.startUpdating()
        try await recorder.startRecording()
        isRecording = recorder.isRecording
        if isRecording, !isPremium {
            FreemiumUsageStore.shared.recordVideoSessionStarted()
        }
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else { return }
        isRecording = false
        recorder.stopRecording { [weak self] result in
            Task { @MainActor in
                self?.isRecording = self?.recorder.isRecording ?? false
                completion(result)
            }
        }
    }

    func teardown(completion: (() -> Void)? = nil) {
        let teardownSignpost = VideoTabPerformance.begin(.teardown)
        locationProvider.stopUpdating()
        isRecording = false
        isSessionReady = false
        isPreviewReady = false
        recorder.pausePreview { _ in
            VideoTabPerformance.end(.teardown, teardownSignpost)
            VideoTabPerformance.mark(.teardownDone)
            completion?()
        }
    }

    func emergencyFinalizeIfRecording() {
        guard recorder.isRecording else { return }
        recorder.emergencyFinalizeForLifecycleEvent()
    }

    private func installRecorderCallbacks() {
        recorder.onSegmentFinished = { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if self.currentSegmentGroupID == nil {
                    self.currentSegmentGroupID = event.segmentGroupID
                }
                self.onSegmentFinished?(event)
            }
        }
        recorder.onRecordingError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.isRecording = false
                self.errorMessage = error.localizedDescription
                self.locationProvider.stopUpdating()
            }
        }
    }

    func switchCamera() {
        guard isSessionReady, !isRecording else { return }
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

    private func configureAudioSessionForVideo(
        backgroundMonitoringEnabled: Bool,
        isMonitoring: Bool
    ) throws {
        if isMonitoring {
            try BackgroundAudioSession.activateForMeasurement(
                backgroundEnabled: backgroundMonitoringEnabled
            )
        } else {
            try BackgroundAudioSession.forceActivateMeasurementForVideoCapture(
                backgroundEnabled: backgroundMonitoringEnabled
            )
        }
    }
}

struct VideoEvidenceView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    @Bindable var coordinator: VideoEvidenceCoordinator
    @Bindable private var subscriptions = SubscriptionManager.shared
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
    @State private var pendingVideoSegments: [VideoSegmentFinishedEvent] = []

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
        .debugView("tab.video")
        .onAppear {
            VideoTabPerformance.mark(.viewAppear)
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .task(id: isTabActive) {
            coordinator.onSegmentFinished = { event in
                pendingVideoSegments.append(event)
            }
            if isTabActive {
                VideoTabPerformance.mark(.taskActiveBegin)
                await coordinator.configure(
                    backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
                    isMonitoring: engine.isMonitoring
                )
                engine.refreshCalibrationOffset()
                lastNoiseSync = .distantPast
                coordinator.syncNoise(from: engine)
                coordinator.syncLocation(from: engine)
                VideoTabPerformance.mark(.syncNoiseDone)
                audioStateManager.restoreMonitoringPipelineIfNeeded()
                VideoTabPerformance.mark(.restoreMonitoringDone)
                VideoTabPerformance.mark(.taskActiveComplete)
            } else {
                VideoTabPerformance.mark(.taskInactiveBegin)
                coordinator.teardown()
                audioStateManager.restoreMonitoringPipelineIfNeeded()
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
            coordinator.syncLocation(from: engine)
        }
        .onChange(of: coordinator.locationProvider.longitude) { _, _ in
            coordinator.syncLocation(from: engine)
        }
        .onChange(of: engine.evidenceLatitude) { _, _ in
            coordinator.syncLocation(from: engine)
        }
        .onChange(of: engine.evidenceLongitude) { _, _ in
            coordinator.syncLocation(from: engine)
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
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                coordinator.syncLocation(from: engine)
            }
            guard !didPromptLocationDenied else { return }
            if status == .denied || status == .restricted {
                didPromptLocationDenied = true
                showLocationPermissionDenied = true
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { presentedVideoURL != nil },
            set: { if !$0 { finishPresentedVideoFromSwipe() } }
        )) {
            if let url = presentedVideoURL {
                SyncedVideoPlayerView(
                    url: url,
                    title: presentedVideoTitle ?? url.lastPathComponent,
                    onDismiss: {
                        clearPresentedVideo()
                    },
                    onPlaybackFinished: {
                        audioStateManager.handlePlaybackFinished()
                    }
                )
            }
        }
    }

    private var previewSection: some View {
        ZStack {
            CameraPreviewView(
                session: coordinator.recorder.captureSessionForPreview,
                isFrontCamera: { coordinator.cameraPosition == .front },
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
            .overlay {
                previewOverlayContent
            }
        }
    }

    private var previewOverlayContent: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                timeLocationOverlay

                if !coordinator.isRecording {
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
                    .disabled(!coordinator.isSessionReady || !coordinator.isPreviewReady)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)

            if previewZoomFactor > 1.05, !coordinator.isRecording {
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

            if coordinator.isRecording {
                VStack(alignment: .trailing, spacing: 6) {
                    if previewZoomFactor > 1.05 {
                        Text(String(format: "%.1fx", previewZoomFactor))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                    }

                    Text(String(format: "%.1f %@", engine.currentDB, engine.effectiveWeighting.rawValue))
                        .font(.caption.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(false)
            }

            if coordinator.isRecording {
                HStack(spacing: 8) {
                    BlinkingRecDot()
                    Text(L10n.videoRecBadge)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }

            if coordinator.isRecording || engine.isMonitoring {
                WaveformView(
                    samples: engine.history,
                    mode: measurementMode,
                    usesCardChrome: false,
                    showsYAxisLabels: false,
                    showsReferenceLimitLine: false,
                    axisLabelColor: .white.opacity(0.7)
                )
                .frame(height: 56)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
            }
        }
    }

    private var timeLocationOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.overlayTimeAndLocationLabel)
                .font(.caption.bold())
                .foregroundStyle(theme.accent)
            Text(Date().formatted(date: .numeric, time: .standard))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
            Text(previewGPSOverlayText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
        }
        .padding(10)
        .background(.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
    }

    private var previewGPSOverlayText: String {
        let coordinates = coordinator.resolvedCoordinates(from: engine)
        if let latitude = coordinates.latitude,
           let longitude = coordinates.longitude {
            return L10n.overlayGpsCoordinates(latitude: latitude, longitude: longitude)
        }
        return L10n.overlayGpsUnavailable
    }

    private var controlSection: some View {
        VStack(spacing: 12) {
            if !engine.isMonitoring || !engine.isHighSensitivityMode {
                Text(L10n.videoAutoMonitoringHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !subscriptions.isPremiumUser {
                let remaining = FreemiumUsageStore.shared.remainingVideoRecordingsToday(isPremium: false)
                Text(L10n.videoFreeQuotaHint(remaining: remaining, maxDuration: Int(FreemiumUsageStore.freeVideoMaxDuration)))
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
                        AppTelemetry.logProductEvent("video_preview_open_tap")
                        Task {
                            do {
                                try audioStateManager.prepareAndStartPlayback()
                                presentedVideoURL = savedVideoURL
                                presentedVideoTitle = savedVideoURL.lastPathComponent
                            } catch {
                                coordinator.errorMessage = error.localizedDescription
                            }
                        }
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
                    AppTelemetry.logProductEvent("video_record_tap")
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
        coordinator.syncLocation(from: engine)
        do {
            try await coordinator.startRecording()
            audioStateManager.restoreMonitoringPipelineIfNeeded()
            AppTelemetry.logVideoRecordingStart()
        } catch {
            coordinator.errorMessage = error.localizedDescription
        }
    }

    private func handleRecordingFinished(_ result: Result<URL, Error>) {
        engine.endTemporaryHighSensitivityForVideoIfNeeded()
        audioStateManager.restoreMonitoringPipelineIfNeeded()
        switch result {
        case .success(let url):
            finishVideoSave(fileURL: url)
        case .failure(let error):
            discardPendingVideoSegments()
            coordinator.errorMessage = error.localizedDescription
        }
    }

    private func finishVideoSave(fileURL: URL) {
        let duration = videoRecordingDuration()
        if !subscriptions.isPremiumUser && duration > FreemiumUsageStore.freeVideoMaxDuration {
            AppTelemetry.logProductEvent(
                "freemium_limit_hit",
                parameters: ["limit_type": "video_duration"]
            )
            PaywallPresenter.shared.present(context: .videoDurationLimit) { purchased in
                if purchased {
                    commitPendingVideoSegments()
                    savedVideoURL = fileURL
                    noteVideoEvidenceSavedForReview()
                } else {
                    discardPendingVideoSegments()
                }
                pendingVideoSegments = []
                coordinator.recordingStartedAt = nil
            }
        } else {
            commitPendingVideoSegments()
            savedVideoURL = fileURL
            noteVideoEvidenceSavedForReview()
            pendingVideoSegments = []
            coordinator.recordingStartedAt = nil
        }
    }

    private func noteVideoEvidenceSavedForReview() {
        let audioTotal = (try? modelContext.fetchCount(FetchDescriptor<RecordingSession>())) ?? 0
        let videoTotal = (try? modelContext.fetchCount(FetchDescriptor<VideoEvidenceSession>())) ?? 0
        let totalFilesCount = audioTotal + videoTotal
        AppReviewStore.updateLatestFilesCount(totalFilesCount)
        if totalFilesCount >= AppReviewStore.minimumFilesForReviewPrompt {
            AppReviewStore.noteCoreFeatureUsed(.evidenceSaved)
        }
        AppReviewStore.evaluatePromptIfEligible(
            isBusy: PaywallPresenter.shared.isPresented || coordinator.isRecording
        )
    }

    private func videoRecordingDuration() -> TimeInterval {
        if let startedAt = coordinator.recordingStartedAt {
            return max(0, Date().timeIntervalSince(startedAt))
        }
        guard let first = pendingVideoSegments.first,
              let last = pendingVideoSegments.last else { return 0 }
        return max(0, last.endedAt.timeIntervalSince(first.startedAt))
    }

    private func commitPendingVideoSegments() {
        for event in pendingVideoSegments {
            persistVideoSegment(event)
        }
    }

    private func discardPendingVideoSegments() {
        for event in pendingVideoSegments {
            try? FileManager.default.removeItem(at: event.fileURL)
            VideoNoiseTimelineStore.remove(for: event.fileURL)
        }
    }

    private func persistVideoSegment(_ event: VideoSegmentFinishedEvent) {
        let coordinates = coordinator.resolvedCoordinates(from: engine)
        let session = VideoEvidenceSession(
            fileName: event.fileURL.lastPathComponent,
            filePath: EvidenceFileResolver.makeRelativePath(from: event.fileURL),
            startedAt: event.startedAt,
            endedAt: event.endedAt,
            peakDB: event.segmentIndex == 1 ? coordinator.peakDB : event.peakDB,
            averageDB: engine.averageDB,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            segmentGroupID: event.segmentGroupID,
            segmentIndex: event.segmentIndex
        )
        modelContext.insert(session)
        try? modelContext.save()
        if event.segmentIndex == 1 || savedVideoURL == nil {
            savedVideoURL = event.fileURL
        }
    }

    private func clearPresentedVideo() {
        presentedVideoURL = nil
        presentedVideoTitle = nil
    }

    private func finishPresentedVideoFromSwipe() {
        audioStateManager.handlePlaybackFinished()
        clearPresentedVideo()
    }
}

private struct BlinkingRecDot: View {
    @State private var isLit = true

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 10, height: 10)
            .opacity(isLit ? 1 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    isLit = false
                }
            }
    }
}
