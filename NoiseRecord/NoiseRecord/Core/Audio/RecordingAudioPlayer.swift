import AVFoundation
import Foundation

@MainActor
@Observable
final class RecordingAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: UUID?
    private(set) var lastErrorMessage: String?
    private var player: AVAudioPlayer?
    private var onPlaybackFinished: (() -> Void)?

    func togglePlayback(
        for session: RecordingSession,
        onPlaybackFinished: @escaping () -> Void
    ) -> String? {
        if playingID == session.id {
            stop(restoreIdleState: true)
            return nil
        }

        stop(restoreIdleState: false)
        self.onPlaybackFinished = onPlaybackFinished
        lastErrorMessage = nil

        do {
            let player = try AVAudioPlayer(contentsOf: session.fileURL)
            player.delegate = self
            player.volume = 1.0
            guard player.prepareToPlay() else {
                throw AudioSessionError.configurationFailed(L10n.errorPlaybackPrepareFailed)
            }
            guard player.play() else {
                throw AudioSessionError.configurationFailed(L10n.errorPlaybackStartFailed)
            }
            self.player = player
            playingID = session.id
            return nil
        } catch {
            self.player = nil
            playingID = nil
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastErrorMessage = message
            onPlaybackFinished()
            return message
        }
    }

    func stopIfPlaying(id: UUID, restoreIdleState: Bool = true) {
        guard playingID == id else { return }
        stop(restoreIdleState: restoreIdleState)
    }

    func stop(restoreIdleState: Bool = true) {
        player?.stop()
        player = nil
        playingID = nil
        if restoreIdleState {
            onPlaybackFinished?()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playingID = nil
            self.onPlaybackFinished?()
        }
    }
}
