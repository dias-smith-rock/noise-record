import AVFoundation
import AVKit
import SwiftUI

struct SyncedVideoPlayerView: View {
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
                .onAppear(perform: startPlayback)
                .onDisappear(perform: stopPlayback)
        }
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
        avPlayer.play()
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
    }
}
