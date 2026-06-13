import AVFoundation
import AVKit
import SwiftUI

struct SyncedVideoPlayerView: View {
    let url: URL
    let title: String
    let timeline: VideoNoiseTimeline?
    let coexistingWithMonitoring: Bool
    let backgroundMonitoringEnabled: Bool
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var currentDecibel: Float?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)

                if let currentDecibel, let timeline {
                    playbackNoiseOverlay(decibel: currentDecibel, weighting: timeline.weighting)
                        .padding(16)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.done, action: onDismiss)
                }
            }
            .onAppear(perform: startPlayback)
            .onDisappear(perform: stopPlayback)
        }
    }

    private func playbackNoiseOverlay(decibel: Float, weighting: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.videoPlaybackSyncedNoise(decibel, weighting: weighting))
                .font(.caption.bold())
                .foregroundStyle(.orange)
            Text(L10n.videoPlaybackSyncedHint)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(10)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
    }

    private func startPlayback() {
        try? AudioSessionManager.configureForPlayback(
            coexistingWithMonitoring: coexistingWithMonitoring,
            backgroundEnabled: backgroundMonitoringEnabled
        )

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = 1.0
        player = avPlayer
        installTimeObserver(on: avPlayer)
        avPlayer.play()
    }

    private func installTimeObserver(on player: AVPlayer) {
        removeTimeObserver()
        guard timeline != nil else { return }

        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let seconds = max(0, CMTimeGetSeconds(time))
            currentDecibel = timeline?.decibel(at: seconds)
        }
    }

    private func removeTimeObserver() {
        guard let player, let timeObserver else { return }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }

    private func stopPlayback() {
        removeTimeObserver()
        player?.pause()
        player = nil
        currentDecibel = nil
    }
}
