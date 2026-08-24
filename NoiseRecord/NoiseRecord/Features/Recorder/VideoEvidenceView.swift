import AVFoundation
import AVKit
import Combine
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
    /// True after video recording claimed / mutated the shared AVAudioSession.
    private(set) var didMutateAudioSessionForVideo = false

    var onSegmentFinished: ((VideoSegmentFinishedEvent) -> Void)?
    /// Installed by `VideoEvidenceView` so tab switches can stop + save before leaving.
    var performStopAndSave: (@MainActor () async -> Void)?

    /// Invalidates in-flight configure / startSession completions when leaving the tab.
    private var configureGeneration = 0
    private var storedBackgroundMonitoringEnabled = false

    func configure(backgroundMonitoringEnabled: Bool, isMonitoring: Bool) async {
        let configureSignpost = VideoTabPerformance.begin(.configureTotal)
        defer { VideoTabPerformance.end(.configureTotal, configureSignpost) }

        configureGeneration += 1
        let generation = configureGeneration
        storedBackgroundMonitoringEnabled = backgroundMonitoringEnabled

        isSessionReady = false
        isPreviewReady = false
        errorMessage = nil

        // Do not start capture (or prompt) until camera is authorized — first-launch ladder owns the prompt.
        guard MediaPermissions.isCameraAuthorized else {
            VideoTabPerformance.mark(.configureComplete)
            return
        }

        do {
            // Idle preview is video-only — do not reconfigure AVAudioSession or open Best GPS.
            // Claiming the measurement session here races with Live monitoring and makes tab switches janky.
            let captureSignpost = VideoTabPerformance.begin(.captureConfigure)
            try await recorder.configureSession(
                backgroundMonitoringEnabled: backgroundMonitoringEnabled
            )
            VideoTabPerformance.end(.captureConfigure, captureSignpost)
            VideoTabPerformance.mark(.captureConfigureDone)

            guard generation == configureGeneration else {
                VideoTabPerformance.mark(.configureCancelled)
                return
            }

            VideoTabPerformance.mark(.captureStartRequested)
            let position = await recorder.startSession()
            guard generation == configureGeneration else {
                VideoTabPerformance.mark(.configureCancelled)
                return
            }
            cameraPosition = position
            isPreviewReady = true
            VideoTabPerformance.mark(.previewReady)

            installRecorderCallbacks()
            isSessionReady = true
            VideoTabPerformance.mark(.uiReady)
            VideoTabPerformance.mark(.configureComplete)
            _ = isMonitoring
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
            PaywallPresenter.shared.present(
                context: .videoDailyLimit,
                triggerFeature: "video_start_blocked"
            )
            return
        }
        guard isSessionReady, isPreviewReady, !isRecording else { return }
        peakDB = 0
        currentSegmentGroupID = nil

        // Claim measurement audio + GPS only when capture actually starts.
        let audioSignpost = VideoTabPerformance.begin(.audioSession)
        try configureAudioSessionForVideo(
            backgroundMonitoringEnabled: storedBackgroundMonitoringEnabled,
            isMonitoring: true
        )
        VideoTabPerformance.end(.audioSession, audioSignpost)
        didMutateAudioSessionForVideo = true
        VideoTabPerformance.mark(.audioSessionDone)
        // Prompt or start GPS for evidence watermark — idle preview no longer opens Best GPS.
        locationProvider.requestPermission()
        VideoTabPerformance.mark(.locationPermissionRequested)

        try await recorder.startRecording()
        isRecording = recorder.isRecording
        // Start the free-quota clock only after capture is actually running.
        recordingStartedAt = isRecording ? Date() : nil
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

    /// Stops GPS + camera preview and awaits `stopRunning` before returning.
    func teardown() async {
        configureGeneration += 1
        VideoTabPerformance.mark(.teardownRequested)
        let teardownSignpost = VideoTabPerformance.begin(.teardown)
        locationProvider.stopUpdating()
        isRecording = false
        isSessionReady = false
        isPreviewReady = false
        _ = await recorder.pausePreview()
        VideoTabPerformance.end(.teardown, teardownSignpost)
        VideoTabPerformance.mark(.teardownDone)
        VideoTabPerformance.mark(.captureStopped)
    }

    /// Returns whether leave-path should rebuild the monitoring pipeline.
    func consumeAudioSessionMutationFlag() -> Bool {
        let mutated = didMutateAudioSessionForVideo
        didMutateAudioSessionForVideo = false
        return mutated
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
    @State private var lastSavedDuration: TimeInterval = 0
    @State private var lastSavedPeakDB: Float = 0
    @State private var lastSavedAnalyticsID: String?
    @State private var presentedVideoURL: URL?
    @State private var presentedVideoTitle: String?
    @State private var previewZoomFactor: CGFloat = 1.0
    @State private var zoomRequestID = 0
    @State private var showCameraPermissionDenied = false
    @State private var showLocationPermissionDenied = false
    @State private var showLocationAccessGuide = false
    @State private var lastNoiseSync = Date.distantPast
    @State private var pendingVideoSegments: [VideoSegmentFinishedEvent] = []
    @State private var isSavingTrimmedClip = false
    @State private var saveBannerMessage: String?
    @State private var recordingTick = Date()
    @State private var isStoppingRecording = false
    @State private var isCameraAuthorized = MediaPermissions.isCameraAuthorized
    private let recordingClock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: L10n.videoTitle, theme: theme)

            // Keep the camera preview outside ScrollView so pinch-out is not stolen.
            previewSection
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 20) {
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
        .onReceive(
            NotificationCenter.default.publisher(for: FirstLaunchPermissionStore.ladderDidFinishNotification)
        ) { _ in
            refreshCameraAuthorizationState()
            Task {
                guard isTabActive else { return }
                await coordinator.configure(
                    backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
                    isMonitoring: engine.isMonitoring
                )
            }
        }
        .task(id: isTabActive) {
            coordinator.onSegmentFinished = { event in
                pendingVideoSegments.append(event)
            }
            coordinator.performStopAndSave = { [self] in
                await stopRecordingAndSaveForTabLeave()
            }
            if isTabActive {
                refreshCameraAuthorizationState()
                VideoTabPerformance.mark(.taskActiveBegin)
                await coordinator.configure(
                    backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
                    isMonitoring: engine.isMonitoring
                )
                guard isTabActive else { return }
                engine.refreshCalibrationOffset()
                lastNoiseSync = .distantPast
                coordinator.syncNoise(from: engine)
                coordinator.syncLocation(from: engine)
                VideoTabPerformance.mark(.syncNoiseDone)
                // Idle preview no longer steals the measurement session — only restore if
                // the engine was already broken, or after a prior recording mutation.
                if !engine.isAudioEngineRunning, audioStateManager.appAudioState == .monitoring {
                    let restoreSignpost = VideoTabPerformance.begin(.restoreMonitoring)
                    VideoTabPerformance.mark(.restoreBegin)
                    audioStateManager.restoreMonitoringPipelineIfNeeded()
                    VideoTabPerformance.end(.restoreMonitoring, restoreSignpost)
                }
                VideoTabPerformance.mark(.restoreMonitoringDone)
                previewZoomFactor = coordinator.recorder.currentZoomFactor
                VideoTabPerformance.mark(.taskActiveComplete)
            } else {
                let leaveSignpost = VideoTabPerformance.begin(.leaveTotal)
                VideoTabPerformance.mark(.taskInactiveBegin)
                coordinator.performStopAndSave = nil
                await coordinator.teardown()
                // Yield so TabView can commit the selection animation before any restore work.
                await Task.yield()
                let shouldRestore = coordinator.consumeAudioSessionMutationFlag()
                    || (audioStateManager.appAudioState == .monitoring && !engine.isAudioEngineRunning)
                if shouldRestore {
                    VideoTabPerformance.mark(.restoreBegin)
                    let restoreSignpost = VideoTabPerformance.begin(.restoreMonitoring)
                    audioStateManager.restoreMonitoringPipelineIfNeeded()
                    VideoTabPerformance.end(.restoreMonitoring, restoreSignpost)
                    VideoTabPerformance.mark(.restoreDone)
                }
                VideoTabPerformance.end(.leaveTotal, leaveSignpost)
                VideoTabPerformance.mark(.taskInactiveComplete)
            }
        }
        .onReceive(recordingClock) { now in
            guard coordinator.isRecording else { return }
            recordingTick = now
            autoStopFreeRecordingIfNeeded()
        }
        .onChange(of: coordinator.cameraPosition) { _, _ in
            previewZoomFactor = coordinator.recorder.currentZoomFactor
        }
        .onChange(of: coordinator.isPreviewReady) { _, ready in
            if ready {
                previewZoomFactor = coordinator.recorder.currentZoomFactor
            }
        }
        .onChange(of: coordinator.isRecording) { wasRecording, isRecording in
            // Error / unexpected stop path — normal stop already cleans up in finalize.
            if wasRecording, !isRecording, !isStoppingRecording, !isPreparingRecording {
                stopMonitoringAfterVideoEvidence()
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
        .alert(
            L10n.permissionLocationDeniedTitle,
            isPresented: $showLocationPermissionDenied
        ) {
            Button(L10n.permissionOpenSettings) {
                #if targetEnvironment(simulator)
                showLocationAccessGuide = true
                #else
                PermissionSettings.openAppSettings()
                #endif
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.permissionLocationDeniedMessage)
        }
        .sheet(isPresented: $showLocationAccessGuide) {
            LocationAccessGuideSheet()
        }
        .onChange(of: coordinator.errorMessage) { _, message in
            guard let message else { return }
            if message.localizedCaseInsensitiveContains("camera") {
                showCameraPermissionDenied = true
            }
        }
        .onChange(of: coordinator.locationProvider.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                coordinator.locationProvider.startUpdating()
                coordinator.syncLocation(from: engine)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { presentedVideoURL != nil },
            set: { if !$0 { finishPresentedVideoFromSwipe() } }
        )) {
            if let url = presentedVideoURL {
                SyncedVideoPlayerView(
                    url: url,
                    title: presentedVideoTitle ?? EvidenceDisplayNaming.listTitle(from: url.lastPathComponent),
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
            if isCameraAuthorized {
                CameraPreviewView(
                    session: coordinator.recorder.captureSessionForPreview,
                    isFrontCamera: { coordinator.cameraPosition == .front },
                    currentZoom: { coordinator.recorder.currentZoomFactor },
                    onZoomChange: { factor in
                        applyPreviewZoom(factor)
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
            } else {
                cameraPermissionPlaceholder
            }
        }
    }

    private var cameraPermissionPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text(L10n.videoCameraPermissionTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(L10n.videoCameraPermissionBody)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await requestCameraAccessFromVideoTab() }
            } label: {
                Text(
                    MediaPermissions.isCameraDenied
                        ? L10n.permissionOpenSettings
                        : L10n.videoCameraPermissionEnable
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .background(Color.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
    }

    private var previewOverlayContent: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                timeLocationOverlay
                    .frame(maxWidth: 200, alignment: .leading)

                if !coordinator.isRecording {
                    Button {
                        zoomRequestID += 1
                        coordinator.switchCamera()
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

            liveLevelTrailingOverlay

            if !coordinator.isRecording, !engine.isMonitoring, savedVideoURL == nil {
                idleTapToMeasureOverlay
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
                .frame(height: VideoNoiseWaveformStripDrawer.livePreviewStripHeight)
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

    @ViewBuilder
    private var liveLevelTrailingOverlay: some View {
        let showZoom = abs(previewZoomFactor - 1.0) > 0.05
        let showLiveLevel = coordinator.isRecording || engine.isMonitoring

        if coordinator.isRecording || showZoom || showLiveLevel {
            VStack(alignment: .trailing, spacing: 6) {
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
                }

                if showZoom {
                    Text(String(format: "%.1fx", previewZoomFactor))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                }

                if showLiveLevel {
                    Text(String(format: "%.1f %@", engine.currentDB, engine.effectiveWeighting.rawValue))
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())

                    if coordinator.isRecording {
                        Text(L10n.videoPeakDB(coordinator.peakDB))
                            .font(.caption2.bold())
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())

                        if !subscriptions.isPremiumUser {
                            Text(L10n.videoFreeRemainingSeconds(recordingRemainingSeconds))
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .foregroundStyle(recordingRemainingSeconds <= 5 ? .orange : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .allowsHitTesting(false)
        }
    }

    private var idleTapToMeasureOverlay: some View {
        VStack(spacing: 8) {
            Text(L10n.videoIdleDbPlaceholder)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))

            Text(L10n.videoIdleTapToMeasure)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var hasGPSFix: Bool {
        let coordinates = coordinator.resolvedCoordinates(from: engine)
        return coordinates.latitude != nil && coordinates.longitude != nil
    }

    private var timeLocationOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.overlayTimeAndLocationLabel)
                .font(.caption.bold())
                .foregroundStyle(theme.accent)
            Text(Date().formatted(date: .numeric, time: .standard))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
            if hasGPSFix {
                Text(previewGPSOverlayText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            } else {
                Button(action: requestVideoLocationAccess) {
                    Text(L10n.overlayGpsUnavailable)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .underline()
                        .lineLimit(2)
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.permissionLocationDeniedTitle)
            }
        }
        .padding(10)
        .background(.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var previewGPSOverlayText: String {
        let coordinates = coordinator.resolvedCoordinates(from: engine)
        if let latitude = coordinates.latitude,
           let longitude = coordinates.longitude {
            return L10n.overlayGpsCoordinates(latitude: latitude, longitude: longitude)
        }
        return L10n.overlayGpsUnavailable
    }

    private func requestVideoLocationAccess() {
        AppTelemetry.logProductEvent("video_gps_unavailable_tap")
        switch coordinator.locationProvider.authorizationStatus {
        case .notDetermined:
            coordinator.locationProvider.requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            coordinator.locationProvider.startUpdating()
            coordinator.syncLocation(from: engine)
        case .denied, .restricted:
            showLocationPermissionDenied = true
        @unknown default:
            showLocationPermissionDenied = true
        }
    }

    private var controlSection: some View {
        VStack(spacing: 12) {
            if coordinator.isRecording {
                recordingHints
            }

            if isSavingTrimmedClip {
                ProgressView(L10n.videoTrimmingProgress)
                    .font(.caption)
            }

            if let saveBannerMessage, savedVideoURL == nil {
                Text(saveBannerMessage)
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                    .multilineTextAlignment(.center)
            }

            if let savedVideoURL, !coordinator.isRecording {
                saveSuccessPanel(for: savedVideoURL)
            } else if isCameraAuthorized {
                if !coordinator.isRecording, !engine.isMonitoring {
                    Text(L10n.videoIdleTapToMeasure)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                recordPrimaryButton
            }
        }
    }

    @ViewBuilder
    private var recordingHints: some View {
        if !subscriptions.isPremiumUser {
            let remaining = FreemiumUsageStore.shared.remainingVideoRecordingsToday(isPremium: false)
            let maxDuration = Int(
                FreemiumUsageStore.shared.allowedVideoSaveDuration(isPremium: false).rounded(.down)
            )
            Text(L10n.videoFreeQuotaHint(remaining: remaining, maxDuration: maxDuration))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func saveSuccessPanel(for url: URL) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Label(
                    L10n.videoSaveSuccessSummary(
                        duration: DurationFormatting.hms(from: lastSavedDuration),
                        peak: lastSavedPeakDB
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
                .multilineTextAlignment(.center)

                Text(L10n.videoSaveSuccessHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let saveBannerMessage {
                    Text(saveBannerMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                AppTelemetry.logProductEvent("video_record_tap", parameters: ["source": "save_success_again"])
                Task { await startEvidenceRecording() }
            } label: {
                Label(L10n.videoRecordAgain, systemImage: "video.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(
                !coordinator.isSessionReady
                    || !coordinator.isPreviewReady
                    || isPreparingRecording
                    || isStoppingRecording
                    || isSavingTrimmedClip
            )

            HStack(spacing: 12) {
                Button {
                    AppTelemetry.logProductEvent("video_preview_open_tap")
                    Task {
                        do {
                            try audioStateManager.prepareAndStartPlayback()
                            presentedVideoURL = url
                            presentedVideoTitle = EvidenceDisplayNaming.listTitle(from: url.lastPathComponent)
                        } catch {
                            coordinator.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Text(L10n.videoPreviewShort)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    let saveID = lastSavedAnalyticsID ?? "unknown"
                    AppTelemetry.logProductEvent(
                        "video_share_tap",
                        parameters: [
                            "source": "save_success",
                            "save_id": saveID,
                        ]
                    )
                    SharePresenter.present(items: [url]) { didShare, activityType in
                        AppTelemetry.logProductEvent(
                            "video_share_result",
                            parameters: [
                                "source": "save_success",
                                "save_id": saveID,
                                "shared": didShare ? "true" : "false",
                                "activity": activityType ?? "none",
                            ]
                        )
                    }
                } label: {
                    Text(L10n.videoShareEvidence)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var recordPrimaryButton: some View {
        Button {
            if coordinator.isRecording {
                requestStopRecording()
            } else {
                AppTelemetry.logProductEvent("video_record_tap")
                Task { await startEvidenceRecording() }
            }
        } label: {
            Group {
                if coordinator.isRecording {
                    let elapsedLabel = DurationFormatting.hms(from: recordingElapsedSeconds)
                    Label {
                        HStack(spacing: 8) {
                            Text(L10n.videoStopAndSave)
                            Text("·")
                                .opacity(0.7)
                            Text(elapsedLabel)
                                .monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: "stop.circle.fill")
                    }
                    .accessibilityLabel(
                        "\(L10n.videoStopAndSave), \(L10n.videoRecordingDurationLabel(elapsedLabel))"
                    )
                } else {
                    Label(
                        L10n.videoStartRecording,
                        systemImage: "video.circle.fill"
                    )
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(coordinator.isRecording ? .red : theme.accent)
        .disabled(
            isPreparingRecording
                || isStoppingRecording
                || isSavingTrimmedClip
                || (coordinator.isRecording == false
                    && isCameraAuthorized
                    && (!coordinator.isSessionReady || !coordinator.isPreviewReady))
        )
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.videoShootingTip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

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
    }

    private func startEvidenceRecording() async {
        guard !coordinator.isRecording else { return }
        isPreparingRecording = true
        savedVideoURL = nil
        lastSavedDuration = 0
        lastSavedPeakDB = 0
        saveBannerMessage = nil
        isStoppingRecording = false
        defer { isPreparingRecording = false }

        let cameraReady = await MediaPermissions.ensureCameraAuthorized()
        refreshCameraAuthorizationState()
        guard cameraReady else {
            if MediaPermissions.isCameraDenied {
                showCameraPermissionDenied = true
            }
            return
        }

        if !coordinator.isSessionReady || !coordinator.isPreviewReady {
            await coordinator.configure(
                backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
                isMonitoring: engine.isMonitoring
            )
        }
        guard coordinator.isSessionReady, coordinator.isPreviewReady else {
            coordinator.errorMessage = L10n.errorVideoCameraUnavailable
            return
        }

        let ready = await engine.ensureMonitoringForVideoEvidence()
        guard ready else {
            coordinator.errorMessage = engine.errorMessage ?? L10n.videoMonitoringStartFailed
            return
        }

        audioStateManager.noteMonitoringStarted()
        coordinator.syncNoise(from: engine)
        coordinator.syncLocation(from: engine)
        do {
            try await coordinator.startRecording()
            // Capture audio attach can interrupt the monitoring graph — rebuild only if needed.
            if !engine.isAudioEngineRunning {
                audioStateManager.restoreMonitoringPipelineIfNeeded()
            }
            AppTelemetry.logVideoRecordingStart()
        } catch {
            stopMonitoringAfterVideoEvidence()
            coordinator.errorMessage = error.localizedDescription
        }
    }

    private func requestCameraAccessFromVideoTab() async {
        if MediaPermissions.isCameraDenied {
            showCameraPermissionDenied = true
            return
        }
        let granted = await MediaPermissions.ensureCameraAuthorized()
        refreshCameraAuthorizationState()
        guard granted else {
            if MediaPermissions.isCameraDenied {
                showCameraPermissionDenied = true
            }
            return
        }
        await coordinator.configure(
            backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
            isMonitoring: engine.isMonitoring
        )
    }

    private func refreshCameraAuthorizationState() {
        isCameraAuthorized = MediaPermissions.isCameraAuthorized
    }

    private func applyPreviewZoom(_ factor: CGFloat) {
        // Keep UI responsive while session-queue applies the real device clamp (may be ~0.5×).
        let minZoom = coordinator.recorder.minZoomFactor
        let maxZoom = coordinator.recorder.maxZoomFactor
        let provisional = max(minZoom, min(factor, maxZoom))
        zoomRequestID += 1
        let requestID = zoomRequestID
        previewZoomFactor = provisional
        coordinator.recorder.setZoomFactor(provisional) { applied in
            guard requestID == zoomRequestID else { return }
            previewZoomFactor = applied
        }
    }

    private func requestStopRecording(reason: String = "manual") {
        guard coordinator.isRecording, !isStoppingRecording else { return }
        isStoppingRecording = true
        coordinator.stopRecording { result in
            Task { @MainActor in
                await finalizeStoppedRecording(result, reason: reason)
                isStoppingRecording = false
            }
        }
    }

    /// Used when the user confirms leaving the Video tab mid-recording.
    private func stopRecordingAndSaveForTabLeave() async {
        guard coordinator.isRecording, !isStoppingRecording else { return }
        isStoppingRecording = true
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<URL, Error>, Never>) in
            coordinator.stopRecording { result in
                continuation.resume(returning: result)
            }
        }
        await finalizeStoppedRecording(result, reason: "tab_leave")
        isStoppingRecording = false
    }

    private var recordingElapsedSeconds: TimeInterval {
        _ = recordingTick
        guard let startedAt = coordinator.recordingStartedAt else { return 0 }
        return max(0, Date().timeIntervalSince(startedAt))
    }

    private var recordingRemainingSeconds: Int {
        let limit = FreemiumUsageStore.shared.allowedVideoSaveDuration(
            isPremium: subscriptions.isPremiumUser
        )
        guard limit.isFinite else { return 0 }
        return max(0, Int((limit - recordingElapsedSeconds).rounded(.down)))
    }

    private func autoStopFreeRecordingIfNeeded() {
        guard coordinator.isRecording, !subscriptions.isPremiumUser, !isStoppingRecording else { return }
        let limit = FreemiumUsageStore.shared.allowedVideoSaveDuration(isPremium: false)
        guard recordingElapsedSeconds >= limit else { return }
        requestStopRecording(reason: "free_limit")
    }

    private func finalizeStoppedRecording(_ result: Result<URL, Error>, reason: String) async {
        stopMonitoringAfterVideoEvidence()
        switch result {
        case .success(let url):
            await finishVideoSave(fileURL: url, stopReason: reason)
        case .failure(let error):
            discardPendingVideoSegments()
            coordinator.errorMessage = error.localizedDescription
        }
    }

    /// Video evidence owns the temporary monitoring session — stop it with the recording.
    private func stopMonitoringAfterVideoEvidence() {
        engine.endTemporaryHighSensitivityForVideoIfNeeded()
        if engine.isMonitoring {
            engine.stopMonitoring(presentSessionSavePrompt: false)
        }
        audioStateManager.noteMonitoringStopped()
    }

    private func finishVideoSave(fileURL: URL, stopReason: String) async {
        saveBannerMessage = nil
        let allowed = FreemiumUsageStore.shared.allowedVideoSaveDuration(
            isPremium: subscriptions.isPremiumUser
        )
        let duration = videoRecordingDuration()
        var didTrim = false
        var hitFreeLimit = stopReason == "free_limit"
        var outputURL = fileURL

        if !subscriptions.isPremiumUser, allowed.isFinite, duration > allowed + 0.15 {
            isSavingTrimmedClip = true
            defer { isSavingTrimmedClip = false }
            do {
                let result = try await VideoEvidenceTrimmer.trimIfNeeded(
                    fileURL: fileURL,
                    maxDuration: allowed
                )
                didTrim = result.didTrim
                if didTrim {
                    outputURL = result.url
                    hitFreeLimit = true
                    AppTelemetry.logProductEvent(
                        "video_trim_applied",
                        parameters: [
                            "limit_seconds": String(Int(allowed)),
                            "original_seconds": String(Int(duration.rounded())),
                        ]
                    )
                    saveBannerMessage = L10n.videoTrimmedSavedHint(seconds: Int(allowed))
                }
            } catch {
                AppTelemetry.logProductEvent(
                    "video_trim_failed",
                    parameters: ["message": error.localizedDescription]
                )
                saveBannerMessage = L10n.videoTrimFailedKeptFullClip
            }
        } else if hitFreeLimit, allowed.isFinite {
            saveBannerMessage = L10n.videoTrimmedSavedHint(seconds: Int(allowed))
        }

        commitPendingVideoSegments()
        if !subscriptions.isPremiumUser {
            FreemiumUsageStore.shared.markFirstClipBonusConsumedIfNeeded()
        }
        let savedDuration = didTrim && allowed.isFinite ? allowed : duration
        lastSavedDuration = savedDuration
        lastSavedPeakDB = coordinator.peakDB
        savedVideoURL = outputURL
        let saveID = UUID().uuidString
        lastSavedAnalyticsID = saveID
        AppTelemetry.logProductEvent(
            "video_save_success",
            parameters: [
                "duration_s": String(Int(savedDuration.rounded())),
                "original_s": String(Int(duration.rounded())),
                "trimmed": didTrim ? "true" : "false",
                "stop_reason": stopReason,
                "save_id": saveID,
            ]
        )
        noteVideoEvidenceSavedForReview()
        pendingVideoSegments = []
        coordinator.recordingStartedAt = nil

        if hitFreeLimit, !subscriptions.isPremiumUser {
            AppTelemetry.logProductEvent(
                "freemium_limit_hit",
                parameters: [
                    "limit_type": "video_duration",
                    "limit_s": allowed.isFinite ? String(Int(allowed.rounded())) : "none",
                    "recorded_s": String(Int(duration.rounded())),
                    "trimmed": didTrim ? "true" : "false",
                ]
            )
            PaywallPresenter.shared.present(
                context: .videoDurationLimit,
                triggerFeature: "video_save_over_limit"
            )
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
