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
    var errorMessage: String?
    var recordingStartedAt: Date?
    var peakDB: Float = 0
    var sessionPeakDB: Float = 0

    func configure(backgroundMonitoringEnabled: Bool, isMonitoring: Bool) async {
        do {
            try configureAudioSessionForVideo(
                backgroundMonitoringEnabled: backgroundMonitoringEnabled,
                isMonitoring: isMonitoring
            )
            try recorder.configureSession()
            recorder.startSession()
            locationProvider.requestPermission()
            locationProvider.startUpdating()
            isSessionReady = true
        } catch {
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

    func startRecording() {
        guard isSessionReady, !isRecording else { return }
        peakDB = 0
        recordingStartedAt = Date()
        recorder.startRecording()
        isRecording = true
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else { return }
        isRecording = false
        recorder.stopRecording(completion: completion)
    }

    func teardown() {
        locationProvider.stopUpdating()
        recorder.stopSession()
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
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = VideoEvidenceCoordinator()
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
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .task {
            await coordinator.configure(
                backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled,
                isMonitoring: engine.isMonitoring
            )
        }
        .onDisappear {
            coordinator.teardown()
            engine.restoreMonitoringAfterExternalSession()
        }
        .onChange(of: engine.currentDB) { _, _ in
            let now = Date()
            let interval = coordinator.isRecording ? 0.1 : 0.25
            guard now.timeIntervalSince(lastNoiseSync) >= interval else { return }
            lastNoiseSync = now
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
                VideoRecordingPlaybackSheet(
                    url: url,
                    title: presentedVideoTitle ?? url.lastPathComponent,
                    coexistingWithMonitoring: engine.isMonitoring,
                    backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled
                ) {
                    presentedVideoURL = nil
                    presentedVideoTitle = nil
                    engine.restoreMonitoringAfterExternalSession()
                }
            }
        }
    }

    private var previewSection: some View {
        ZStack(alignment: .bottomLeading) {
            CameraPreviewView(
                session: coordinator.recorder.captureSessionForPreview,
                currentZoom: { coordinator.recorder.currentZoomFactor },
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

            if previewZoomFactor > 1.05 {
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
                Text(coordinator.recorder.dataBridge.overlayDecibelText)
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
                ProMetricCard(title: L10n.videoCurrentDb, value: String(format: "%.1f", engine.currentDB), theme: theme)
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
            .disabled(!coordinator.isSessionReady || isPreparingRecording)
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
        guard coordinator.isSessionReady, !coordinator.isRecording else { return }
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
        coordinator.startRecording()
    }

    private func handleRecordingFinished(_ result: Result<URL, Error>) {
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
            FilesTabBadgeStore.markPending()
            savedVideoURL = url
        case .failure(let error):
            coordinator.errorMessage = error.localizedDescription
        }
    }
}

private struct VideoRecordingPlaybackSheet: View {
    let url: URL
    let title: String
    let coexistingWithMonitoring: Bool
    let backgroundMonitoringEnabled: Bool
    let onDismiss: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.done, action: onDismiss)
                    }
                }
                .onAppear {
                    try? AudioSessionManager.configureForPlayback(
                        coexistingWithMonitoring: coexistingWithMonitoring,
                        backgroundEnabled: backgroundMonitoringEnabled
                    )
                    let item = AVPlayerItem(url: url)
                    let avPlayer = AVPlayer(playerItem: item)
                    avPlayer.volume = 1.0
                    player = avPlayer
                    avPlayer.play()
                }
                .onDisappear {
                    player?.pause()
                    player = nil
                }
        }
    }
}
