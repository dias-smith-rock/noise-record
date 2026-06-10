import AVFoundation
import AVKit
import SwiftData
import SwiftUI

private enum RecordingListTab: String, CaseIterable, Identifiable {
    case video = "Video"
    case audio = "Voice"

    var id: String { rawValue }
}

private enum RecordingSortOption: String, CaseIterable, Identifiable {
    case dateDescending = "Date (newest)"
    case dateAscending = "Date (oldest)"
    case peakDescending = "Peak (high)"
    case peakAscending = "Peak (low)"
    case nameAscending = "Name (A–Z)"

    var id: String { rawValue }
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
    @Query private var sessions: [RecordingSession]
    @Query private var videoSessions: [VideoEvidenceSession]
    @Environment(\.modelContext) private var modelContext

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

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    private var sortedAudioSessions: [RecordingSession] {
        sort(sessions)
    }

    private var sortedVideoSessions: [VideoEvidenceSession] {
        sort(videoSessions)
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

            Picker("Type", selection: $selectedTab) {
                ForEach(RecordingListTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .onChange(of: selectedTab) { _, _ in
                exitSelectionMode()
            }

            ScrollView {
                VStack(spacing: 20) {
                    summaryBar
                    listContent
                }
                .padding()
            }

            if isSelectionMode {
                selectionActionBar
            }
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .fullScreenCover(isPresented: Binding(
            get: { presentedVideoURL != nil },
            set: { if !$0 { dismissVideoPlayer() } }
        )) {
            if let url = presentedVideoURL {
                VideoPlaybackSheet(
                    url: url,
                    title: presentedVideoTitle ?? url.lastPathComponent,
                    coexistingWithMonitoring: engine.isMonitoring,
                    backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled
                ) {
                    dismissVideoPlayer()
                    restoreMonitoringAudioSession()
                }
            }
        }
        .alert("Rename", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("File name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") { applyRename() }
        } message: {
            Text("The original extension is kept if you omit it.")
        }
        .confirmationDialog(
            "Delete \(selectedCount) selected item(s)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        }
        .task { repairStoredMediaPaths() }
        .alert("Cannot Play", isPresented: Binding(
            get: { playbackErrorMessage != nil },
            set: { if !$0 { playbackErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { playbackErrorMessage = nil }
        } message: {
            Text(playbackErrorMessage ?? "")
        }
    }

    private var pageHeader: some View {
        ProTabHeader(title: "Files", theme: theme) {
            if isSelectionMode {
                ProTabHeaderTextButton(
                    title: isAllSelectedInCurrentTab ? "Deselect All" : "Select All",
                    theme: theme
                ) {
                    toggleSelectAll()
                }
                ProTabHeaderTextButton(title: "Cancel", theme: theme) {
                    exitSelectionMode()
                }
            } else {
                ProTabHeaderIconButton(systemImage: "arrow.up.arrow.down", theme: theme) {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(RecordingSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
                ProTabHeaderCapsuleButton(
                    title: "Select",
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
                Text("\(selectedCount) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        switch selectedTab {
        case .video:
            if sortedVideoSessions.isEmpty {
                ProEmptyState(
                    title: "No videos yet",
                    message: "Record a video with dB overlay on the Video tab to see it here.",
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
                            onDelete: { deleteVideo(video) },
                            onRename: { beginRename(.video(video)) },
                            onToggleSelection: { toggleVideoSelection(video.id) }
                        )
                    }
                }
            }

        case .audio:
            if sortedAudioSessions.isEmpty {
                ProEmptyState(
                    title: "No recordings yet",
                    message: "Enable voice-activated recording on the Voice tab; sounds above threshold are saved here.",
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
    }

    private var currentTabIsEmpty: Bool {
        selectedTab == .audio ? sessions.isEmpty : videoSessions.isEmpty
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            switch selectedTab {
            case .audio:
                ProMetricCard(title: "Clips", value: "\(sessions.count)", theme: theme)
                ProMetricCard(title: "Duration", value: formattedAudioTotalDuration, theme: theme)
                ProMetricCard(
                    title: "Peak",
                    value: sessions.isEmpty ? "—" : "\(Int(sessions.map(\.peakDB).max() ?? 0))",
                    theme: theme
                )
            case .video:
                ProMetricCard(title: "Videos", value: "\(videoSessions.count)", theme: theme)
                ProMetricCard(title: "Duration", value: formattedVideoTotalDuration, theme: theme)
                ProMetricCard(
                    title: "Peak",
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
        var badges = ["Peak \(Int(video.peakDB)) dB"]
        if let lat = video.latitude, let lon = video.longitude {
            badges.append(String(format: "%.4f, %.4f", lat, lon))
        }
        return badges
    }

    private func audioBadges(for session: RecordingSession) -> [String] {
        var badges = ["Peak \(Int(session.peakDB)) dB", "Avg \(Int(session.averageDB)) dB"]
        if let type = session.noiseType {
            badges.append(type)
        }
        return badges
    }

    private func audioDetailLine(for session: RecordingSession) -> String {
        "\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(Int(session.duration))s"
    }

    // MARK: - Playback

    private func playVideo(_ session: VideoEvidenceSession) {
        guard !isSelectionMode else {
            toggleVideoSelection(session.id)
            return
        }
        markVideoAsRead(session)
        guard session.fileExists else {
            playbackErrorMessage = "Video file not found: \(session.fileName)"
            return
        }
        audioPlayerController.stop(restoreSession: true)
        try? AudioSessionManager.configureForPlayback(
            coexistingWithMonitoring: engine.isMonitoring,
            backgroundEnabled: engine.backgroundMonitoringEnabled
        )
        presentedVideoURL = session.fileURL
        presentedVideoTitle = session.fileName
    }

    private func dismissVideoPlayer() {
        presentedVideoURL = nil
        presentedVideoTitle = nil
    }

    private func restoreMonitoringAudioSession() {
        AudioSessionManager.restoreMeasurementIfMonitoring(
            engine.isMonitoring,
            backgroundEnabled: engine.backgroundMonitoringEnabled
        )
    }

    private func toggleAudioPlayback(_ session: RecordingSession) {
        guard !isSelectionMode else {
            toggleAudioSelection(session.id)
            return
        }
        markAudioAsRead(session)
        guard session.fileExists else {
            playbackErrorMessage = "Audio file not found: \(session.fileName)"
            return
        }
        audioPlayerController.togglePlayback(
            for: session,
            coexistingWithMonitoring: engine.isMonitoring,
            backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled
        ) {
            restoreMonitoringAudioSession()
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
            playbackErrorMessage = "Audio file not found: \(session.fileName)"
            return
        }
        SharePresenter.present(items: [session.fileURL])
    }

    private func shareMedia(_ session: VideoEvidenceSession) {
        guard session.fileExists else {
            playbackErrorMessage = "Video file not found: \(session.fileName)"
            return
        }
        SharePresenter.present(items: [session.fileURL])
    }

    // MARK: - Delete

    private func deleteAudio(_ session: RecordingSession) {
        audioPlayerController.stopIfPlaying(id: session.id)
        try? FileManager.default.removeItem(at: session.fileURL)
        modelContext.delete(session)
        selectedAudioIDs.remove(session.id)
    }

    private func deleteVideo(_ session: VideoEvidenceSession) {
        if presentedVideoURL == session.fileURL {
            dismissVideoPlayer()
        }
        try? FileManager.default.removeItem(at: session.fileURL)
        modelContext.delete(session)
        selectedVideoIDs.remove(session.id)
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
            update(newURL)
        } catch {
            // Keep original name on failure.
        }
    }
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
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.accent, theme.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(fileName)
                            .font(.subheadline.bold())
                            .lineLimit(2)
                            .truncationMode(.middle)

                        if isNew {
                            Text("New")
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
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            onRename()
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
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
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
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

// MARK: - Video player

private struct VideoPlaybackSheet: View {
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
                        Button("Done", action: onDismiss)
                    }
                }
                .onAppear {
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
                .onDisappear {
                    player?.pause()
                    player = nil
                }
        }
    }
}
