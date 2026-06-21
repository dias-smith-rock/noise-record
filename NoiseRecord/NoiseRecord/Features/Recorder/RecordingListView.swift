import AVFoundation
import AVKit
import SwiftData
import SwiftUI

private enum RecordingListTab: CaseIterable, Identifiable {
    case video
    case audio

    var id: Self { self }

    var title: String {
        switch self {
        case .video: L10n.filesTabVideo
        case .audio: L10n.filesTabVoice
        }
    }
}

private enum RecordingSortOption: CaseIterable, Identifiable {
    case dateDescending
    case dateAscending
    case peakDescending
    case peakAscending
    case nameAscending

    var id: Self { self }

    var title: String {
        switch self {
        case .dateDescending: L10n.filesSortDateDesc
        case .dateAscending: L10n.filesSortDateAsc
        case .peakDescending: L10n.filesSortPeakDesc
        case .peakAscending: L10n.filesSortPeakAsc
        case .nameAscending: L10n.filesSortNameAsc
        }
    }
}

private enum RenameTarget: Identifiable {
    case audio(RecordingSession)
    case video(VideoEvidenceSession)

    var id: UUID {
        switch self {
        case .audio(let session): session.id
        case .video(let session): session.id
        }
    }

    var currentName: String {
        switch self {
        case .audio(let session): session.fileName
        case .video(let session): session.fileName
        }
    }

    var fileExtension: String {
        (currentName as NSString).pathExtension
    }
}

struct RecordingListView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    let isTabActive: Bool
    @Query(sort: \RecordingSession.startedAt, order: .reverse) private var sessions: [RecordingSession]
    @Query(sort: \VideoEvidenceSession.startedAt, order: .reverse) private var videoSessions: [VideoEvidenceSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguageRevision) private var appLanguageRevision

    @State private var selectedTab: RecordingListTab = .audio
    @State private var sortOption: RecordingSortOption = .dateDescending
    @State private var isSelectionMode = false
    @State private var selectedAudioIDs: Set<UUID> = []
    @State private var selectedVideoIDs: Set<UUID> = []

    @State private var audioPlayerController = RecordingAudioPlayer()
    @State private var presentedVideoURL: URL?
    @State private var presentedVideoTitle: String?

    @State private var renameTarget: RenameTarget?
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var playbackErrorMessage: String?
    @State private var renameErrorMessage: String?
    @State private var toastMessage: String?
    @State private var showPhotoPermissionDenied = false
    @State private var saveToPhotosErrorMessage: String?
    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    private var sortedAudioSessions: [RecordingSession] {
        switch sortOption {
        case .dateDescending: sessions
        default: sort(sessions)
        }
    }

    private var sortedVideoSessions: [VideoEvidenceSession] {
        switch sortOption {
        case .dateDescending: videoSessions
        default: sort(videoSessions)
        }
    }

    private var selectedCount: Int {
        selectedTab == .audio ? selectedAudioIDs.count : selectedVideoIDs.count
    }

    private var currentTabItemCount: Int {
        selectedTab == .audio ? sortedAudioSessions.count : sortedVideoSessions.count
    }

    private var isAllSelectedInCurrentTab: Bool {
        currentTabItemCount > 0 && selectedCount == currentTabItemCount
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader

            Picker(L10n.filesPickerType, selection: $selectedTab) {
                ForEach(RecordingListTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .id(appLanguageRevision)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .onChange(of: selectedTab) { _, _ in
                exitSelectionMode()
            }

            TabView(selection: $selectedTab) {
                filesTabPage(.video) {
                    videoListContent
                }
                .tag(RecordingListTab.video)

                filesTabPage(.audio) {
                    audioListContent
                }
                .tag(RecordingListTab.audio)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if isSelectionMode {
                selectionActionBar
            }
        }
        .observesAppLanguage()
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .fullScreenCover(isPresented: Binding(
            get: { presentedVideoURL != nil },
            set: { if !$0 { finishVideoPlaybackFromSwipe() } }
        )) {
            if let url = presentedVideoURL {
                SyncedVideoPlayerView(
                    url: url,
                    title: presentedVideoTitle ?? url.lastPathComponent,
                    onDismiss: {
                        clearVideoPresentation()
                    },
                    onPlaybackFinished: {
                        audioStateManager.handlePlaybackFinished()
                    }
                )
            }
        }
        .alert(L10n.filesRenameTitle, isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField(L10n.filesRenamePlaceholder, text: $renameText)
            Button(L10n.cancel, role: .cancel) { renameTarget = nil }
            Button(L10n.save) { applyRename() }
        } message: {
            Text(L10n.filesRenameMessage)
        }
        .confirmationDialog(
            L10n.filesDeleteConfirm(selectedCount),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) { deleteSelected() }
            Button(L10n.cancel, role: .cancel) {}
        }
        .task { repairStoredMediaPaths() }
        .alert(L10n.filesPlaybackErrorTitle, isPresented: Binding(
            get: { playbackErrorMessage != nil },
            set: { if !$0 { playbackErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { playbackErrorMessage = nil }
        } message: {
            Text(playbackErrorMessage ?? "")
        }
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { renameErrorMessage != nil },
            set: { if !$0 { renameErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { renameErrorMessage = nil }
        } message: {
            Text(renameErrorMessage ?? "")
        }
        .permissionDeniedAlert(
            isPresented: $showPhotoPermissionDenied,
            title: L10n.permissionPhotosDeniedTitle,
            message: L10n.permissionPhotosDeniedMessage
        )
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { saveToPhotosErrorMessage != nil },
            set: { if !$0 { saveToPhotosErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { saveToPhotosErrorMessage = nil }
        } message: {
            Text(saveToPhotosErrorMessage ?? "")
        }
        .proToast(message: $toastMessage)
    }

    private var pageHeader: some View {
        ProTabHeader(title: L10n.filesTitle, theme: theme) {
            if isSelectionMode {
                ProTabHeaderTextButton(
                    title: isAllSelectedInCurrentTab ? L10n.filesDeselectAll : L10n.filesSelectAll,
                    theme: theme
                ) {
                    toggleSelectAll()
                }
                ProTabHeaderTextButton(title: L10n.cancel, theme: theme) {
                    exitSelectionMode()
                }
            } else {
                ProTabHeaderIconButton(systemImage: "arrow.up.arrow.down", theme: theme) {
                    Picker(L10n.filesPickerSort, selection: $sortOption) {
                        ForEach(RecordingSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
                ProTabHeaderCapsuleButton(
                    title: L10n.filesSelect,
                    theme: theme,
                    disabled: currentTabIsEmpty
                ) {
                    isSelectionMode = true
                }
            }
        }
    }

    private var selectionActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 20) {
                Text(L10n.filesSelectedCount(selectedCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    shareSelected()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(L10n.filesBatchShare)
                .disabled(selectedCount == 0)

                if selectedTab == .video {
                    Button {
                        Task { await saveSelectedToPhotos() }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(L10n.filesBatchSaveToPhotos)
                    .disabled(selectedCount == 0)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(L10n.delete)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func filesTabPage<Content: View>(
        _ tab: RecordingListTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            if isTabActive {
                VStack(spacing: 20) {
                    summaryBar(for: tab)
                    content()
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var videoListContent: some View {
        if sortedVideoSessions.isEmpty {
            ProEmptyState(
                title: L10n.filesEmptyVideoTitle,
                message: L10n.filesEmptyVideoMessage,
                systemImage: "video.slash",
                theme: theme
            )
        } else {
            VStack(spacing: 12) {
                ForEach(sortedVideoSessions) { video in
                    MediaListCard(
                        fileName: video.fileName,
                        isNew: video.isNew,
                        subtitle: video.startedAt.formatted(date: .abbreviated, time: .standard),
                        badges: videoBadges(for: video),
                        isPlaying: false,
                        playIcon: "play.rectangle.fill",
                        theme: theme,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedVideoIDs.contains(video.id),
                        onPlay: { playVideo(video) },
                        onShare: { shareMedia(video) },
                        onSaveToPhotos: { Task { await saveVideoToPhotos(video) } },
                        onDelete: { deleteVideo(video) },
                        onRename: { beginRename(.video(video)) },
                        onToggleSelection: { toggleVideoSelection(video.id) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var audioListContent: some View {
        if sortedAudioSessions.isEmpty {
            ProEmptyState(
                title: L10n.filesEmptyAudioTitle,
                message: L10n.filesEmptyAudioMessage,
                systemImage: "waveform",
                theme: theme
            )
        } else {
            VStack(spacing: 12) {
                ForEach(sortedAudioSessions) { session in
                    MediaListCard(
                        fileName: session.fileName,
                        isNew: session.isNew,
                        subtitle: nil,
                        detailLine: audioDetailLine(for: session),
                        badges: audioBadges(for: session),
                        isPlaying: audioPlayerController.playingID == session.id,
                        playIcon: audioPlayerController.playingID == session.id ? "stop.circle.fill" : "play.circle.fill",
                        theme: theme,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedAudioIDs.contains(session.id),
                        onPlay: { toggleAudioPlayback(session) },
                        onShare: { shareMedia(session) },
                        onDelete: { deleteAudio(session) },
                        onRename: { beginRename(.audio(session)) },
                        onToggleSelection: { toggleAudioSelection(session.id) }
                    )
                }
            }
        }
    }

    private var currentTabIsEmpty: Bool {
        if !isTabActive { return true }
        return selectedTab == .audio ? sessions.isEmpty : videoSessions.isEmpty
    }

    private func summaryBar(for tab: RecordingListTab) -> some View {
        HStack(spacing: 12) {
            switch tab {
            case .audio:
                ProMetricCard(title: L10n.filesSummaryClips, value: "\(sessions.count)", theme: theme)
                ProMetricCard(title: L10n.filesSummaryDuration, value: formattedAudioTotalDuration, theme: theme)
                ProMetricCard(
                    title: L10n.filesSummaryPeak,
                    value: sessions.isEmpty ? "—" : "\(Int(sessions.map(\.peakDB).max() ?? 0))",
                    theme: theme
                )
            case .video:
                ProMetricCard(title: L10n.filesSummaryVideos, value: "\(videoSessions.count)", theme: theme)
                ProMetricCard(title: L10n.filesSummaryDuration, value: formattedVideoTotalDuration, theme: theme)
                ProMetricCard(
                    title: L10n.filesSummaryPeak,
                    value: videoSessions.isEmpty ? "—" : "\(Int(videoSessions.map(\.peakDB).max() ?? 0))",
                    theme: theme
                )
            }
        }
    }

    private var formattedAudioTotalDuration: String {
        formatDuration(sessions.reduce(0) { $0 + $1.duration })
    }

    private var formattedVideoTotalDuration: String {
        formatDuration(videoSessions.reduce(0) { $0 + $1.duration })
    }

    private func formatDuration(_ total: TimeInterval) -> String {
        if total < 60 { return "\(Int(total))s" }
        return "\(Int(total / 60))m"
    }

    private func sort(_ items: [RecordingSession]) -> [RecordingSession] {
        switch sortOption {
        case .dateDescending: items.sorted { $0.startedAt > $1.startedAt }
        case .dateAscending: items.sorted { $0.startedAt < $1.startedAt }
        case .peakDescending: items.sorted { $0.peakDB > $1.peakDB }
        case .peakAscending: items.sorted { $0.peakDB < $1.peakDB }
        case .nameAscending: items.sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        }
    }

    private func sort(_ items: [VideoEvidenceSession]) -> [VideoEvidenceSession] {
        switch sortOption {
        case .dateDescending: items.sorted { $0.startedAt > $1.startedAt }
        case .dateAscending: items.sorted { $0.startedAt < $1.startedAt }
        case .peakDescending: items.sorted { $0.peakDB > $1.peakDB }
        case .peakAscending: items.sorted { $0.peakDB < $1.peakDB }
        case .nameAscending: items.sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        }
    }

    private func videoBadges(for video: VideoEvidenceSession) -> [String] {
        var badges = [L10n.filesPeakBadge(Int(video.peakDB))]
        if let lat = video.latitude, let lon = video.longitude {
            badges.append(String(format: "%.4f, %.4f", lat, lon))
        }
        if let hash = truncatedHash(video.fileHash) {
            badges.append("\(L10n.filesFileHash) \(hash)")
        }
        return badges
    }

    private func audioBadges(for session: RecordingSession) -> [String] {
        var badges = [L10n.filesPeakBadge(Int(session.peakDB)), L10n.filesAvgBadge(Int(session.averageDB))]
        if let type = session.noiseType {
            badges.append(type)
        }
        if let hash = truncatedHash(session.fileHash) {
            badges.append("\(L10n.filesFileHash) \(hash)")
        }
        return badges
    }

    private func truncatedHash(_ hash: String?) -> String? {
        guard let hash, !hash.isEmpty else { return nil }
        return String(hash.prefix(8))
    }

    private func audioDetailLine(for session: RecordingSession) -> String {
        L10n.filesAudioDetailLine(
            date: session.startedAt.formatted(date: .abbreviated, time: .shortened),
            duration: Int(session.duration)
        )
    }

    // MARK: - Playback

    private func playVideo(_ session: VideoEvidenceSession) {
        guard !isSelectionMode else {
            toggleVideoSelection(session.id)
            return
        }
        markVideoAsRead(session)
        guard session.fileExists else {
            playbackErrorMessage = L10n.filesVideoNotFound(session.fileName)
            return
        }
        audioPlayerController.stop(restoreIdleState: true)
        do {
            try audioStateManager.prepareAndStartPlayback()
        } catch {
            playbackErrorMessage = error.localizedDescription
            return
        }
        presentedVideoURL = session.fileURL
        presentedVideoTitle = session.fileName
    }

    private func clearVideoPresentation() {
        presentedVideoURL = nil
        presentedVideoTitle = nil
    }

    private func finishVideoPlaybackFromSwipe() {
        audioStateManager.handlePlaybackFinished()
        clearVideoPresentation()
    }

    private func toggleAudioPlayback(_ session: RecordingSession) {
        guard !isSelectionMode else {
            toggleAudioSelection(session.id)
            return
        }
        markAudioAsRead(session)
        guard session.fileExists else {
            playbackErrorMessage = L10n.filesAudioNotFound(session.fileName)
            return
        }
        if audioPlayerController.playingID == session.id {
            audioPlayerController.stop(restoreIdleState: true)
            return
        }

        do {
            try audioStateManager.prepareAndStartPlayback()
        } catch {
            playbackErrorMessage = error.localizedDescription
            return
        }

        if let error = audioPlayerController.togglePlayback(for: session, onPlaybackFinished: {
            audioStateManager.handlePlaybackFinished()
        }) {
            audioStateManager.handlePlaybackFinished()
            playbackErrorMessage = error
        }
    }

    private func markAudioAsRead(_ session: RecordingSession) {
        guard session.isNew else { return }
        session.isNew = false
        try? modelContext.save()
    }

    private func markVideoAsRead(_ session: VideoEvidenceSession) {
        guard session.isNew else { return }
        session.isNew = false
        try? modelContext.save()
    }

    private func repairStoredMediaPaths() {
        var didRepair = false

        for session in sessions {
            if let repaired = EvidenceFileResolver.repairedRelativePath(
                storedPath: session.filePath,
                fileName: session.fileName,
                folder: .recordings
            ) {
                session.filePath = repaired
                didRepair = true
            }
        }

        for session in videoSessions {
            if let repaired = EvidenceFileResolver.repairedRelativePath(
                storedPath: session.filePath,
                fileName: session.fileName,
                folder: .videoEvidence
            ) {
                session.filePath = repaired
                didRepair = true
            }
        }

        if didRepair {
            try? modelContext.save()
        }
    }

    // MARK: - Selection

    private func toggleAudioSelection(_ id: UUID) {
        if selectedAudioIDs.contains(id) {
            selectedAudioIDs.remove(id)
        } else {
            selectedAudioIDs.insert(id)
        }
    }

    private func toggleVideoSelection(_ id: UUID) {
        if selectedVideoIDs.contains(id) {
            selectedVideoIDs.remove(id)
        } else {
            selectedVideoIDs.insert(id)
        }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedAudioIDs.removeAll()
        selectedVideoIDs.removeAll()
    }

    private func toggleSelectAll() {
        switch selectedTab {
        case .audio:
            if isAllSelectedInCurrentTab {
                selectedAudioIDs.removeAll()
            } else {
                selectedAudioIDs = Set(sortedAudioSessions.map(\.id))
            }
        case .video:
            if isAllSelectedInCurrentTab {
                selectedVideoIDs.removeAll()
            } else {
                selectedVideoIDs = Set(sortedVideoSessions.map(\.id))
            }
        }
    }

    private func shareMedia(_ session: RecordingSession) {
        guard session.fileExists else {
            playbackErrorMessage = L10n.filesAudioNotFound(session.fileName)
            return
        }
        SharePresenter.present(items: [session.fileURL])
    }

    private func shareMedia(_ session: VideoEvidenceSession) {
        guard session.fileExists else {
            playbackErrorMessage = L10n.filesVideoNotFound(session.fileName)
            return
        }
        SharePresenter.present(items: [session.fileURL])
    }

    @MainActor
    private func saveVideoToPhotos(_ session: VideoEvidenceSession) async {
        guard session.fileExists else {
            playbackErrorMessage = L10n.filesVideoNotFound(session.fileName)
            return
        }

        let authorized = await PhotoLibrarySaver.requestAddOnlyAccess()
        guard authorized else {
            showPhotoPermissionDenied = true
            return
        }

        do {
            let kind = try await PhotoLibrarySaver.saveFile(at: session.fileURL)
            toastMessage = PhotoLibrarySaver.successMessage(for: kind)
        } catch {
            saveToPhotosErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveSelectedToPhotos() async {
        guard selectedTab == .video else { return }

        let items = videoSessions.filter { selectedVideoIDs.contains($0.id) && $0.fileExists }
        guard !items.isEmpty else { return }

        let authorized = await PhotoLibrarySaver.requestAddOnlyAccess()
        guard authorized else {
            showPhotoPermissionDenied = true
            return
        }

        let urls = items.map(\.fileURL)
        do {
            if urls.count == 1, let url = urls.first {
                let kind = try await PhotoLibrarySaver.saveFile(at: url)
                toastMessage = PhotoLibrarySaver.successMessage(for: kind)
            } else {
                try await PhotoLibrarySaver.saveFiles(at: urls)
                toastMessage = L10n.playerSavedItemsToPhotos(urls.count)
            }
        } catch {
            saveToPhotosErrorMessage = error.localizedDescription
        }
    }

    private func shareSelected() {
        let urls: [URL]
        switch selectedTab {
        case .audio:
            urls = sessions
                .filter { selectedAudioIDs.contains($0.id) && $0.fileExists }
                .map(\.fileURL)
        case .video:
            urls = videoSessions
                .filter { selectedVideoIDs.contains($0.id) && $0.fileExists }
                .map(\.fileURL)
        }
        guard !urls.isEmpty else { return }
        SharePresenter.present(items: urls)
    }

    // MARK: - Delete

    private func deleteAudio(_ session: RecordingSession) {
        audioPlayerController.stopIfPlaying(id: session.id)
        try? FileManager.default.removeItem(at: session.fileURL)
        modelContext.delete(session)
        selectedAudioIDs.remove(session.id)
        try? modelContext.save()
    }

    private func deleteVideo(_ session: VideoEvidenceSession) {
        if presentedVideoURL == session.fileURL {
            finishVideoPlaybackFromSwipe()
        }
        try? FileManager.default.removeItem(at: session.fileURL)
        VideoNoiseTimelineStore.remove(for: session.fileURL)
        modelContext.delete(session)
        selectedVideoIDs.remove(session.id)
        try? modelContext.save()
    }

    private func deleteSelected() {
        if selectedTab == .audio {
            let targets = sessions.filter { selectedAudioIDs.contains($0.id) }
            targets.forEach { deleteAudio($0) }
        } else {
            let targets = videoSessions.filter { selectedVideoIDs.contains($0.id) }
            targets.forEach { deleteVideo($0) }
        }
        try? modelContext.save()
        exitSelectionMode()
    }

    // MARK: - Rename

    private func beginRename(_ target: RenameTarget) {
        let name = (target.currentName as NSString).deletingPathExtension
        renameText = name
        renameTarget = target
    }

    private func applyRename() {
        guard let target = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch target {
        case .audio(let session):
            renameFile(
                session: session,
                newBaseName: trimmed,
                extension: target.fileExtension.isEmpty ? "m4a" : target.fileExtension
            ) { url in
                session.fileName = url.lastPathComponent
                session.filePath = EvidenceFileResolver.makeRelativePath(from: url)
                session.fileHash = RecordingSession.hashFile(at: url.path)
            }
        case .video(let session):
            renameFile(
                session: session,
                newBaseName: trimmed,
                extension: target.fileExtension.isEmpty ? "mp4" : target.fileExtension
            ) { url in
                session.fileName = url.lastPathComponent
                session.filePath = EvidenceFileResolver.makeRelativePath(from: url)
                session.fileHash = VideoEvidenceSession.hashFile(at: url.path)
            }
        }

        try? modelContext.save()
        renameTarget = nil
    }

    private func renameFile<T>(
        session: T,
        newBaseName: String,
        extension ext: String,
        update: (URL) -> Void
    ) {
        let sanitized = newBaseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let finalName = "\(sanitized).\(ext)"

        let oldURL: URL
        switch session {
        case let audio as RecordingSession: oldURL = audio.fileURL
        case let video as VideoEvidenceSession: oldURL = video.fileURL
        default: return
        }

        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(finalName)
        guard newURL != oldURL else { return }

        if FileManager.default.fileExists(atPath: newURL.path) {
            try? FileManager.default.removeItem(at: newURL)
        }
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            if session is VideoEvidenceSession {
                try? VideoNoiseTimelineStore.moveSidecar(from: oldURL, to: newURL)
            }
            update(newURL)
        } catch {
            renameErrorMessage = L10n.filesRenameFailed
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Shared card

private struct MediaListCard: View {
    let fileName: String
    var isNew: Bool = false
    let subtitle: String?
    var detailLine: String?
    let badges: [String]
    let isPlaying: Bool
    let playIcon: String
    let theme: ModeVisualTheme
    let isSelectionMode: Bool
    let isSelected: Bool
    let onPlay: () -> Void
    let onShare: () -> Void
    var onSaveToPhotos: (() -> Void)?
    let onDelete: () -> Void
    let onRename: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        ProCard(theme: theme) {
            HStack(alignment: .top, spacing: 12) {
                if isSelectionMode {
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isSelected ? theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onPlay) {
                    Image(systemName: playIcon)
                        .font(.system(size: 36))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(fileName)
                            .font(.subheadline.bold())
                            .lineLimit(2)
                            .truncationMode(.middle)

                        if isNew {
                            Text(L10n.filesBadgeNew)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let detailLine {
                        Text(detailLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    FlowBadgeRow(badges: badges, theme: theme)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isSelectionMode {
                    Menu {
                        Button(action: onShare) {
                            Label(L10n.share, systemImage: "square.and.arrow.up")
                        }
                        if let onSaveToPhotos {
                            Button(action: onSaveToPhotos) {
                                Label(L10n.playerSaveToPhotos, systemImage: "square.and.arrow.down")
                            }
                        }
                        Button {
                            onRename()
                        } label: {
                            Label(L10n.rename, systemImage: "pencil")
                        }
                        Button(role: .destructive, action: onDelete) {
                            Label(L10n.delete, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            } else {
                onPlay()
            }
        }
        .contextMenu {
            if !isSelectionMode {
                Button(action: onShare) {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                }
                if let onSaveToPhotos {
                    Button(action: onSaveToPhotos) {
                        Label(L10n.playerSaveToPhotos, systemImage: "square.and.arrow.down")
                    }
                }
                Button(action: onRename) {
                    Label(L10n.rename, systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label(L10n.delete, systemImage: "trash")
                }
            }
        }
    }
}

private struct FlowBadgeRow: View {
    let badges: [String]
    let theme: ModeVisualTheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(badges.indices, id: \.self) { index in
                Text(badges[index])
                    .font(.caption2.bold())
                    .foregroundStyle(index == 0 ? theme.accent : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(index == 0 ? theme.badgeBackground : Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    .lineLimit(1)
            }
        }
    }
}
