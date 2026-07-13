import AVFoundation
import AVKit
import SwiftUI

struct SyncedVideoPlayerView: View {
    let url: URL
    let title: String
    var initialToastMessage: String? = nil
    let onDismiss: () -> Void
    let onPlaybackFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var currentTime: TimeInterval = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var timeline: VideoNoiseTimeline?
    @State private var isLoadingTimeline = false
    @State private var timelineError: String?
    @State private var isSavingToPhotos = false
    @State private var showPhotoPermissionDenied = false
    @State private var saveErrorMessage: String?
    @State private var toastMessage: String?

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: DeviceCalibrationStore.isHighSensitivityMode)
    }

    private var hasWaveformTimeline: Bool {
        guard let timeline else { return false }
        return !timeline.samples.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)

                if isLoadingTimeline {
                    ProgressView(L10n.mediaDetailAnalyzingWaveform)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 24)
                } else if hasWaveformTimeline, let timeline {
                    VideoWaveformOverlayView(
                        timeline: timeline,
                        playbackDuration: effectivePlaybackDuration,
                        currentTime: currentTime,
                        mode: measurementMode,
                        onSeek: { seek(to: $0) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.done) {
                        finishPlaybackAndDismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await saveVideoToPhotoLibrary() }
                    } label: {
                        if isSavingToPhotos {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    .accessibilityLabel(L10n.playerSaveToPhotos)
                    .disabled(isSavingToPhotos)
                }
            }
            .onAppear {
                if let initialToastMessage {
                    toastMessage = initialToastMessage
                }
                startPlayback()
            }
            .onDisappear(perform: stopPlayback)
            .task(id: url) {
                await loadTimeline()
            }
            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
                guard let item = notification.object as? AVPlayerItem,
                      item === player?.currentItem else { return }
                onPlaybackFinished()
            }
        }
        .permissionDeniedAlert(
            isPresented: $showPhotoPermissionDenied,
            title: L10n.permissionPhotosDeniedTitle,
            message: L10n.permissionPhotosDeniedMessage
        )
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { timelineError != nil },
            set: { if !$0 { timelineError = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { timelineError = nil }
        } message: {
            Text(timelineError ?? "")
        }
        .proToast(message: $toastMessage)
    }

    private var effectivePlaybackDuration: TimeInterval {
        if playbackDuration > 0 { return playbackDuration }
        if let timelineDuration = timeline?.timelineDuration, timelineDuration > 0 {
            return timelineDuration
        }
        return 0
    }

    private func startPlayback() {
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = 1.0
        player = avPlayer
        attachTimeObserver(to: avPlayer)
        avPlayer.play()
    }

    private func attachTimeObserver(to avPlayer: AVPlayer) {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
            if let itemDuration = avPlayer.currentItem?.duration.seconds,
               itemDuration.isFinite, itemDuration > 0 {
                playbackDuration = itemDuration
            }
        }
    }

    private func seek(to time: TimeInterval) {
        let clamped = min(max(time, 0), max(effectivePlaybackDuration, 0))
        currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func loadTimeline() async {
        isLoadingTimeline = true
        timelineError = nil
        defer { isLoadingTimeline = false }

        let fileDuration = await RecordingWaveformAnalyzer.mediaDuration(for: url)
        if fileDuration > 0 {
            playbackDuration = fileDuration
        }

        do {
            let loaded = try await RecordingWaveformAnalyzer.playbackTimeline(for: url)
            timeline = loaded
            if playbackDuration <= 0, loaded.timelineDuration > 0 {
                playbackDuration = loaded.timelineDuration
            }
        } catch {
            timelineError = error.localizedDescription
            if let cached = RecordingWaveformAnalyzer.loadCachedTimeline(for: url) {
                timeline = cached
                if playbackDuration <= 0, cached.timelineDuration > 0 {
                    playbackDuration = cached.timelineDuration
                }
            } else if var cached = VideoNoiseTimelineStore.load(for: url), !cached.samples.isEmpty {
                if fileDuration > 0,
                   let normalized = cached.normalized(to: fileDuration, source: cached.source ?? .live) {
                    cached = normalized
                }
                timeline = cached
                if playbackDuration <= 0, cached.timelineDuration > 0 {
                    playbackDuration = cached.timelineDuration
                }
            }
        }
    }

    private func stopPlayback() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
    }

    private func finishPlaybackAndDismiss() {
        onPlaybackFinished()
        onDismiss()
    }

    @MainActor
    private func saveVideoToPhotoLibrary() async {
        guard !isSavingToPhotos else { return }
        isSavingToPhotos = true
        defer { isSavingToPhotos = false }

        let authorized = await PhotoLibrarySaver.requestAddOnlyAccess()
        guard authorized else {
            showPhotoPermissionDenied = true
            return
        }

        do {
            let kind = try await PhotoLibrarySaver.saveFile(at: url)
            toastMessage = PhotoLibrarySaver.successMessage(for: kind)
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
