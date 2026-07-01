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

        if isVideo {
            let player = AVPlayer(url: url)
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
        let clamped = min(max(time, 0), max(duration, 0))
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

    private func attachVideoTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            currentTime = time.seconds
            if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
                duration = itemDuration
            }
            if currentTime >= duration, duration > 0 {
                isPlaying = false
            }
        }
    }

    private func startAudioTimer() {
        stopAudioTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let audioPlayer else { return }
            currentTime = audioPlayer.currentTime
            duration = audioPlayer.duration
            if !audioPlayer.isPlaying {
                isPlaying = false
                stopAudioTimer()
            }
        }
    }

    private func stopAudioTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}
