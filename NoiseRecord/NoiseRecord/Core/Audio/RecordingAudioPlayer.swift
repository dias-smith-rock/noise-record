import AVFoundation
import Foundation

@MainActor
@Observable
final class RecordingAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: UUID?
    private var player: AVAudioPlayer?
    private var onRestoreSession: (() -> Void)?

    func togglePlayback(
        for session: RecordingSession,
        coexistingWithMonitoring: Bool,
        backgroundMonitoringEnabled: Bool,
        onRestoreSession: @escaping () -> Void
    ) {
        if playingID == session.id {
            stop(restoreSession: true)
            return
        }

        stop(restoreSession: false)
        self.onRestoreSession = onRestoreSession

        do {
            try AudioSessionManager.configureForPlayback(
                coexistingWithMonitoring: coexistingWithMonitoring,
                backgroundEnabled: backgroundMonitoringEnabled
            )
            let player = try AVAudioPlayer(contentsOf: session.fileURL)
            player.delegate = self
            player.volume = 1.0
            guard player.prepareToPlay() else {
                throw AudioSessionError.configurationFailed("无法准备音频文件。")
            }
            guard player.play() else {
                throw AudioSessionError.configurationFailed("音频播放启动失败。")
            }
            self.player = player
            playingID = session.id
        } catch {
            self.player = nil
            playingID = nil
            onRestoreSession()
        }
    }

    func stopIfPlaying(id: UUID, restoreSession: Bool = true) {
        guard playingID == id else { return }
        stop(restoreSession: restoreSession)
    }

    func stop(restoreSession: Bool = true) {
        player?.stop()
        player = nil
        playingID = nil
        if restoreSession {
            onRestoreSession?()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playingID = nil
            self.onRestoreSession?()
        }
    }
}
