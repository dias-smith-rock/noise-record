import AVFoundation
import AVKit
import SwiftUI

struct SyncedVideoPlayerView: View {
    let url: URL
    let title: String
    var initialToastMessage: String? = nil
    var fallbackDuration: TimeInterval = 0
    let onDismiss: () -> Void
    let onPlaybackFinished: () -> Void

    @Bindable private var subscriptions = SubscriptionManager.shared
    @State private var player: AVPlayer?
    @State private var resolvedDuration: TimeInterval = 0
    @State private var timeObserver: Any?
    @State private var rateObservation: NSKeyValueObservation?
    /// True after the free wall was hit and VIP was shown (or weekly credit consumed).
    @State private var didHitPreviewLimit = false
    @State private var weeklyPreviewUnlocked = false
    @State private var isVIPPaywallPresented = false
    @State private var isSavingToPhotos = false
    @State private var showPhotoPermissionDenied = false
    @State private var saveErrorMessage: String?
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            // Full asset is loaded; VIP restriction only pauses at the free preview wall.
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
                    ToolbarItemGroup(placement: .primaryAction) {
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

                        Button {
                            shareCurrentVideo()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(L10n.share)
                    }
                }
                .onAppear {
                    if let initialToastMessage {
                        toastMessage = initialToastMessage
                    }
                    resolvedDuration = fallbackDuration
                    weeklyPreviewUnlocked = false
                    didHitPreviewLimit = false
                    startPlayback()
                }
                .onDisappear(perform: stopPlayback)
                .onChange(of: subscriptions.isPremiumUser) { _, isPremium in
                    guard isPremium else { return }
                    weeklyPreviewUnlocked = true
                    didHitPreviewLimit = false
                    if isVIPPaywallPresented {
                        isVIPPaywallPresented = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
                    guard let item = notification.object as? AVPlayerItem,
                          item === player?.currentItem else { return }
                    // Natural end of the full video only — never treat the 3s pause as finished.
                    onPlaybackFinished()
                }
        }
        // Host VIP sheet on the preview itself so the fullScreenCover stays open.
        .sheet(isPresented: $isVIPPaywallPresented, onDismiss: {
            PaywallPresenter.shared.handleSheetDismissed()
            if subscriptions.isPremiumUser {
                weeklyPreviewUnlocked = true
                didHitPreviewLimit = false
                player?.play()
            } else {
                // Allow the next Play tap to present VIP again.
                didHitPreviewLimit = false
                player?.pause()
                snapToPreviewLimitIfNeeded()
            }
        }) {
            PaywallView(context: .mediaPreviewLimit)
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

    private var previewLimit: TimeInterval? {
        MediaEntitlementGate.previewPlaybackLimit(
            duration: resolvedDuration > 0 ? resolvedDuration : fallbackDuration,
            isPremium: subscriptions.isPremiumUser,
            weeklyPreviewUnlocked: weeklyPreviewUnlocked
        )
    }

    private func startPlayback() {
        let item = AVPlayerItem(url: url)
        item.forwardPlaybackEndTime = .invalid
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = 1.0
        player = avPlayer
        attachTimeObserver(to: avPlayer)
        attachRateObserver(to: avPlayer)
        avPlayer.play()
    }

    private func attachTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if let itemDuration = player.currentItem?.duration.seconds,
               itemDuration.isFinite,
               itemDuration > 0 {
                resolvedDuration = itemDuration
            }

            guard let limit = previewLimit else { return }

            if time.seconds > limit + 0.05 {
                snapToPreviewLimitIfNeeded()
                enforcePreviewLimitWhilePlaying()
                return
            }

            if time.seconds >= limit - 0.02 {
                enforcePreviewLimitWhilePlaying()
            }
        }
    }

    private func attachRateObserver(to player: AVPlayer) {
        rateObservation?.invalidate()
        rateObservation = player.observe(\.rate, options: [.new]) { observed, _ in
            Task { @MainActor in
                guard observed.rate > 0 else { return }
                enforcePreviewLimitWhilePlaying()
            }
        }
    }

    /// When playback is attempted at/after the free wall, pause and show VIP again.
    private func enforcePreviewLimitWhilePlaying() {
        guard let limit = previewLimit else { return }
        guard let player else { return }

        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds >= limit - 0.02 else { return }

        player.pause()
        snapToPreviewLimitIfNeeded()
        presentVIPPaywallIfNeeded()
    }

    private func snapToPreviewLimitIfNeeded() {
        guard let limit = previewLimit, let player else { return }
        let cmTime = CMTime(seconds: limit, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func presentVIPPaywallIfNeeded() {
        guard !isVIPPaywallPresented else { return }

        if MediaEntitlementGate.consumeWeeklyFullPreviewIfAvailable(triggerFeature: "video_preview_cap") {
            weeklyPreviewUnlocked = true
            didHitPreviewLimit = false
            player?.play()
            return
        }

        didHitPreviewLimit = true
        PaywallPresenter.shared.arm(
            context: .mediaPreviewLimit,
            triggerFeature: "video_preview_cap"
        ) { purchased in
            if purchased {
                weeklyPreviewUnlocked = true
                didHitPreviewLimit = false
                player?.play()
            }
        }
        isVIPPaywallPresented = true
    }

    private func stopPlayback() {
        rateObservation?.invalidate()
        rateObservation = nil
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

        AppTelemetry.logProductEvent(
            "video_save_to_photos_tap",
            parameters: [
                "source": "preview",
                "count": "1",
            ]
        )

        guard MediaEntitlementGate.requireExportAccess(triggerFeature: "video_save_to_photos_preview") else {
            AppTelemetry.logProductEvent(
                "video_save_to_photos_result",
                parameters: [
                    "source": "preview",
                    "status": "vip_gate",
                    "count": "1",
                ]
            )
            return
        }

        isSavingToPhotos = true
        defer { isSavingToPhotos = false }

        let authorized = await PhotoLibrarySaver.requestAddOnlyAccess()
        guard authorized else {
            showPhotoPermissionDenied = true
            AppTelemetry.logProductEvent(
                "video_save_to_photos_result",
                parameters: [
                    "source": "preview",
                    "status": "permission_denied",
                    "count": "1",
                ]
            )
            return
        }

        do {
            let kind = try await PhotoLibrarySaver.saveFile(at: url)
            AppTelemetry.logProductEvent(
                "video_save_to_photos",
                parameters: [
                    "source": "preview",
                    "count": "1",
                ]
            )
            AppTelemetry.logProductEvent(
                "video_save_to_photos_result",
                parameters: [
                    "source": "preview",
                    "status": "success",
                    "count": "1",
                ]
            )
            toastMessage = PhotoLibrarySaver.successMessage(for: kind)
        } catch {
            saveErrorMessage = error.localizedDescription
            AppTelemetry.logProductEvent(
                "video_save_to_photos_result",
                parameters: [
                    "source": "preview",
                    "status": "error",
                    "count": "1",
                ]
            )
        }
    }

    private func shareCurrentVideo() {
        player?.pause()
        AppTelemetry.logProductEvent(
            "video_share_tap",
            parameters: ["source": "preview"]
        )
        guard MediaEntitlementGate.requireShareAccess(triggerFeature: "video_share_preview") else {
            AppTelemetry.logProductEvent(
                "video_share_result",
                parameters: [
                    "source": "preview",
                    "shared": "false",
                    "activity": "vip_gate",
                ]
            )
            return
        }
        SharePresenter.present(items: [url]) { didShare, activityType in
            AppTelemetry.logProductEvent(
                "video_share_result",
                parameters: [
                    "source": "preview",
                    "shared": didShare ? "true" : "false",
                    "activity": activityType ?? "none",
                ]
            )
        }
    }
}
