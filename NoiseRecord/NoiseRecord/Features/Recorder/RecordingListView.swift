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

enum MediaDetailRoute: Hashable {
    case audio(UUID)
    case video(UUID)
}

private struct FilesTabSummary: Equatable {
    var clipCount: Int
    var durationLabel: String
    var peakLabel: String

    static let empty = FilesTabSummary(clipCount: 0, durationLabel: "—", peakLabel: "—")
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

    @State private var detailRoute: MediaDetailRoute?
    @State private var waveformReloadVersions: [String: Int] = [:]
    @State private var lastDetailFileURL: URL?

    @State private var audioSummary = FilesTabSummary.empty
    @State private var videoSummary = FilesTabSummary.empty

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

            filesListPage

            if isSelectionMode {
                selectionActionBar
            }
        }
        .observesAppLanguage()
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .navigationDestination(item: $detailRoute) { route in
            switch route {
            case .audio(let id):
                if let session = sessions.first(where: { $0.id == id }) {
                    MediaEvidenceDetailView(
                        kind: .audio(session),
                        audioStateManager: audioStateManager
                    )
                }
            case .video(let id):
                if let session = videoSessions.first(where: { $0.id == id }) {
                    MediaEvidenceDetailView(
                        kind: .video(session),
                        audioStateManager: audioStateManager
                    )
                }
            }
        }
        .onChange(of: detailRoute) { _, route in
            if route == nil, let fileURL = lastDetailFileURL {
                WaveformThumbnailCache.invalidate(for: fileURL)
                let key = fileURL.standardizedFileURL.path
                waveformReloadVersions[key, default: 0] += 1
                lastDetailFileURL = nil
            }
        }
        .onChange(of: sessions.count) { _, _ in
            refreshAudioSummary()
        }
        .onChange(of: videoSessions.count) { _, _ in
            refreshVideoSummary()
        }
        .onChange(of: isTabActive) { _, active in
            guard active else { return }
            refreshAudioSummary()
            refreshVideoSummary()
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
        .task(id: isTabActive) {
            guard isTabActive else { return }
            await Task.yield()
            repairStoredMediaPaths()
            refreshAudioSummary()
            refreshVideoSummary()
        }
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

    private var filesListPage: some View {
        ScrollView {
            if isTabActive {
                LazyVStack(spacing: 20) {
                    summaryBar(for: selectedTab)

                    switch selectedTab {
                    case .audio:
                        audioListContent
                    case .video:
                        videoListContent
                    }
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
            LazyVStack(spacing: 12) {
                ForEach(sortedVideoSessions) { video in
                    MediaListCard(
                        fileName: video.fileName,
                        isNew: video.isNew,
                        subtitle: nil,
                        detailLine: video.startedAt.formatted(date: .abbreviated, time: .shortened),
                        playFooterText: DurationFormatting.hms(from: video.duration),
                        badges: videoBadges(for: video),
                        isPlaying: false,
                        playIcon: "play.rectangle.fill",
                        theme: theme,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedVideoIDs.contains(video.id),
                        onOpen: { openVideoDetail(video) },
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
            LazyVStack(spacing: 12) {
                ForEach(sortedAudioSessions) { session in
                    MediaListCard(
                        fileName: session.fileName,
                        isNew: session.isNew,
                        subtitle: nil,
                        detailLine: session.recordingStartDate.formatted(date: .abbreviated, time: .shortened),
                        playFooterText: DurationFormatting.hms(from: session.duration),
                        waveformFileURL: session.fileURL,
                        waveformAlternateURLs: waveformAlternateURLs(for: session),
                        waveformMode: measurementMode,
                        waveformReloadToken: waveformReloadVersions[session.fileURL.standardizedFileURL.path, default: 0],
                        badges: [],
                        isPlaying: false,
                        playIcon: "play.circle.fill",
                        theme: theme,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedAudioIDs.contains(session.id),
                        onOpen: { openAudioDetail(session) },
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

    @ViewBuilder
    private func summaryBar(for tab: RecordingListTab) -> some View {
        let summary = tab == .audio ? audioSummary : videoSummary
        HStack(spacing: 12) {
            switch tab {
            case .audio:
                ProMetricCard(title: L10n.filesSummaryClips, value: "\(summary.clipCount)", theme: theme)
                ProMetricCard(title: L10n.filesSummaryDuration, value: summary.durationLabel, theme: theme)
                ProMetricCard(title: L10n.filesSummaryPeak, value: summary.peakLabel, theme: theme)
            case .video:
                ProMetricCard(title: L10n.filesSummaryVideos, value: "\(summary.clipCount)", theme: theme)
                ProMetricCard(title: L10n.filesSummaryDuration, value: summary.durationLabel, theme: theme)
                ProMetricCard(title: L10n.filesSummaryPeak, value: summary.peakLabel, theme: theme)
            }
        }
    }

    private func refreshAudioSummary() {
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let peak = sessions.map(\.peakDB).max() ?? 0
        audioSummary = FilesTabSummary(
            clipCount: sessions.count,
            durationLabel: formatDuration(totalDuration),
            peakLabel: sessions.isEmpty ? "—" : "\(Int(peak))"
        )
    }

    private func refreshVideoSummary() {
        let totalDuration = videoSessions.reduce(0) { $0 + $1.duration }
        let peak = videoSessions.map(\.peakDB).max() ?? 0
        videoSummary = FilesTabSummary(
            clipCount: videoSessions.count,
            durationLabel: formatDuration(totalDuration),
            peakLabel: videoSessions.isEmpty ? "—" : "\(Int(peak))"
        )
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

    private func truncatedHash(_ hash: String?) -> String? {
        guard let hash, !hash.isEmpty else { return nil }
        return String(hash.prefix(8))
    }

    // MARK: - Detail navigation

    private func openAudioDetail(_ session: RecordingSession) {
        guard !isSelectionMode else {
            toggleAudioSelection(session.id)
            return
        }
        guard session.fileExists else {
            playbackErrorMessage = L10n.filesAudioNotFound(session.fileName)
            return
        }
        detailRoute = .audio(session.id)
        lastDetailFileURL = session.fileURL
    }

    private func waveformAlternateURLs(for session: RecordingSession) -> [URL] {
        let preferred = session.preferredFileURL
        let resolved = session.fileURL
        guard preferred != resolved else { return [] }
        return [preferred]
    }

    private func openVideoDetail(_ session: VideoEvidenceSession) {
        guard !isSelectionMode else {
            toggleVideoSelection(session.id)
            return
        }
        guard session.fileExists else {
            playbackErrorMessage = L10n.filesVideoNotFound(session.fileName)
            return
        }
        detailRoute = .video(session.id)
        lastDetailFileURL = session.fileURL
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
        WaveformThumbnailCache.invalidate(
            for: session.fileURL,
            alternateURLs: waveformAlternateURLs(for: session)
        )
        try? FileManager.default.removeItem(at: session.fileURL)
        VideoNoiseTimelineStore.remove(for: session.fileURL)
        modelContext.delete(session)
        selectedAudioIDs.remove(session.id)
        try? modelContext.save()
    }

    private func deleteVideo(_ session: VideoEvidenceSession) {
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
            try? VideoNoiseTimelineStore.moveSidecar(from: oldURL, to: newURL)
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
    var playFooterText: String?
    var waveformFileURL: URL?
    var waveformAlternateURLs: [URL] = []
    var waveformMode: AcousticMeasurementMode?
    var waveformReloadToken: Int = 0
    var badges: [String] = []
    let isPlaying: Bool
    let playIcon: String
    let theme: ModeVisualTheme
    let isSelectionMode: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onShare: () -> Void
    var onSaveToPhotos: (() -> Void)?
    let onDelete: () -> Void
    let onRename: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        ProCard(theme: theme) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    if isSelectionMode {
                        onToggleSelection()
                    } else {
                        onOpen()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        if isSelectionMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isSelected ? theme.accent : .secondary)
                        }

                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: playIcon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(theme.accent)

                                if isNew {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 4, y: -4)
                                }
                            }

                            if let playFooterText {
                                Text(playFooterText)
                                    .font(.caption2.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .frame(width: 52)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(fileName)
                                .font(.subheadline.bold())
                                .lineLimit(2)
                                .truncationMode(.middle)
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

                            if let waveformFileURL, let waveformMode {
                                RecordingWaveformThumbnailView(
                                    fileURL: waveformFileURL,
                                    alternateFileURLs: waveformAlternateURLs,
                                    mode: waveformMode,
                                    reloadToken: waveformReloadToken
                                )
                            } else if !badges.isEmpty {
                                FlowBadgeRow(badges: badges, theme: theme)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

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
            .frame(maxWidth: .infinity, alignment: .leading)
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
