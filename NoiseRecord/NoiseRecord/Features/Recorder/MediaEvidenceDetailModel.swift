import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class MediaEvidenceDetailModel {
    var timeline: VideoNoiseTimeline?
    var isLoadingTimeline = false
    var timelineError: String?
    var currentTime: TimeInterval = 0
    var isPlaying = false
    var duration: TimeInterval = 0
    var waveformReferenceLimitDB = NoiseReferenceLimits.residentialNightDB
    /// Set when free preview hits the 3s cap (VIP paywall presented or weekly unlock used).
    var didHitPreviewLimit = false
    /// True after consuming this week's free full-preview allowance for the current item.
    private(set) var weeklyPreviewUnlocked = false

    private var audioPlayer: AVAudioPlayer?
    private var videoPlayer: AVPlayer?
    private var timeObserver: Any?
    private var playbackTimer: Timer?
    private var mediaURL: URL?
    private var isVideo = false

    var hasWaveformTimeline: Bool {
        guard let timeline else { return false }
        return !timeline.samples.isEmpty
    }

    var playbackDuration: TimeInterval {
        if duration > 0 { return duration }
        if let timelineDuration = timeline?.timelineDuration, timelineDuration > 0 {
            return timelineDuration
        }
        return 0
    }

    var previewLimit: TimeInterval? {
        MediaEntitlementGate.previewPlaybackLimit(
            duration: playbackDuration,
            weeklyPreviewUnlocked: weeklyPreviewUnlocked
        )
    }

    func loadTimeline(from url: URL, isVideo: Bool) async {
        guard !isLoadingTimeline else { return }
        isLoadingTimeline = true
        timelineError = nil
        defer { isLoadingTimeline = false }

        do {
            timeline = try await RecordingWaveformAnalyzer.loadOrAnalyze(fileURL: url)
        } catch {
            timelineError = error.localizedDescription
            if let cached = VideoNoiseTimelineStore.load(for: url),
               cached.isValidForPlaybackAlignment {
                timeline = cached
            }
        }
    }

    func configurePlayback(
        url: URL,
        isVideo: Bool,
        fallbackDuration: TimeInterval
    ) throws {
        cleanupPlayers()
        mediaURL = url
        self.isVideo = isVideo
        duration = fallbackDuration
        didHitPreviewLimit = false
        weeklyPreviewUnlocked = false

        if isVideo {
            let player = AVPlayer(url: url)
            // Full asset timeline — restriction is enforced by pausing at 3s, not truncating the item.
            player.currentItem?.forwardPlaybackEndTime = .invalid
            videoPlayer = player
            attachVideoTimeObserver(to: player)
        } else {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayer = player
            duration = player.duration
        }
        currentTime = 0
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        // At/after the free wall: don't restart silently — re-trigger VIP gate.
        if let limit = previewLimit, currentTime >= limit - 0.02 {
            handlePreviewLimitReached(forcePresentPaywall: true)
            return
        }
        if isVideo {
            videoPlayer?.play()
        } else {
            audioPlayer?.play()
            startAudioTimer()
        }
        isPlaying = true
    }

    func pause() {
        if isVideo {
            videoPlayer?.pause()
        } else {
            audioPlayer?.pause()
            stopAudioTimer()
        }
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        let clamped = MediaEntitlementGate.clampSeekTime(
            time,
            duration: max(duration, playbackDuration),
            weeklyPreviewUnlocked: weeklyPreviewUnlocked
        )
        currentTime = clamped
        if isVideo {
            let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
            videoPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            audioPlayer?.currentTime = clamped
        }
    }

    func videoPlayerBinding() -> AVPlayer? {
        videoPlayer
    }

    func cleanup() {
        pause()
        cleanupPlayers()
    }

    private func cleanupPlayers() {
        stopAudioTimer()
        if let timeObserver, let videoPlayer {
            videoPlayer.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        videoPlayer?.pause()
        videoPlayer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func handlePreviewLimitReached(forcePresentPaywall: Bool = false) {
        pause()
        if let limit = previewLimit {
            seek(to: limit)
        }
        if !forcePresentPaywall {
            guard !didHitPreviewLimit else { return }
        }
        didHitPreviewLimit = true

        // Weekly free credit continues playback; otherwise stop and show VIP paywall.
        if MediaEntitlementGate.tryUnlockFullPreview(triggerFeature: "media_preview_cap") {
            weeklyPreviewUnlocked = true
            didHitPreviewLimit = false
            if isVideo {
                videoPlayer?.play()
            } else {
                audioPlayer?.play()
                startAudioTimer()
            }
            isPlaying = true
        }
        // If paywall was shown: keep didHitPreviewLimit == true until the user taps Play again
        // (`forcePresentPaywall`), which re-opens VIP without auto-restarting from 0s.
    }

    private func attachVideoTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                if let itemDuration = player.currentItem?.duration.seconds,
                   itemDuration.isFinite,
                   itemDuration > 0 {
                    self.duration = itemDuration
                }
                if let limit = self.previewLimit, self.currentTime >= limit - 0.02 {
                    self.handlePreviewLimitReached()
                    return
                }
                if self.currentTime >= self.duration, self.duration > 0 {
                    self.isPlaying = false
                }
            }
        }
    }

    private func startAudioTimer() {
        stopAudioTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let audioPlayer = self.audioPlayer else { return }
                self.currentTime = audioPlayer.currentTime
                self.duration = audioPlayer.duration
                if let limit = self.previewLimit, self.currentTime >= limit - 0.02 {
                    self.handlePreviewLimitReached()
                    return
                }
                if !audioPlayer.isPlaying {
                    self.isPlaying = false
                    self.stopAudioTimer()
                }
            }
        }
    }

    private func stopAudioTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}
