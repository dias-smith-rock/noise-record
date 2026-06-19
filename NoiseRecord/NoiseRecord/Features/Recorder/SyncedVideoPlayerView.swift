import AVFoundation
import AVKit
import SwiftUI

struct SyncedVideoPlayerView: View {
    let url: URL
    let title: String
    let onDismiss: () -> Void
    let onPlaybackFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var isSavingToPhotos = false
    @State private var showPhotoPermissionDenied = false
    @State private var saveErrorMessage: String?
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea(edges: .bottom)
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
                .onAppear(perform: startPlayback)
                .onDisappear(perform: stopPlayback)
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
        .proToast(message: $toastMessage)
    }

    private func startPlayback() {
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
