import AVFoundation
import AVKit
import SwiftData
import SwiftUI

private enum RecordingListTab: String, CaseIterable, Identifiable {
    case video = "录像"
    case audio = "声控录音"

    var id: String { rawValue }
}

private enum RecordingSortOption: String, CaseIterable, Identifiable {
    case dateDescending = "时间（新→旧）"
    case dateAscending = "时间（旧→新）"
    case peakDescending = "峰值（高→低）"
    case peakAscending = "峰值（低→高）"
    case nameAscending = "名称（A→Z）"

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

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var renameTarget: RenameTarget?
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

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

    var body: some View {
        VStack(spacing: 0) {
            Picker("类型", selection: $selectedTab) {
                ForEach(RecordingListTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
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
        }
        .proTabBackground(theme: theme)
        .navigationTitle("录音记录")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ProShareSheet(items: [shareURL])
            }
        }
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
        .alert("重命名", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("文件名", text: $renameText)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("保存") { applyRename() }
        } message: {
            Text("不含扩展名时将自动保留原格式。")
        }
        .confirmationDialog(
            "删除选中的 \(selectedCount) 项？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { deleteSelected() }
            Button("取消", role: .cancel) {}
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("排序", selection: $sortOption) {
                    ForEach(RecordingSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Label("排序", systemImage: "arrow.up.arrow.down")
                    .foregroundStyle(theme.accent)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if isSelectionMode {
                Button("取消") { exitSelectionMode() }
            } else {
                Button("选择") { isSelectionMode = true }
                    .disabled(currentTabIsEmpty)
            }
        }

        if isSelectionMode {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Text("已选 \(selectedCount) 项")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .disabled(selectedCount == 0)
                }
            }
        }

        if selectedTab == .audio, !sessions.isEmpty, !isSelectionMode {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    shareURL = CSVExporter.exportRecordingSessions(sessions)
                    showShare = true
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        switch selectedTab {
        case .video:
            if sortedVideoSessions.isEmpty {
                ProEmptyState(
                    title: "暂无录像",
                    message: "在「录像」页录制带分贝水印的视频后，将显示在此。",
                    systemImage: "video.slash",
                    theme: theme
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedVideoSessions) { video in
                        MediaListCard(
                            fileName: video.fileName,
                            subtitle: video.startedAt.formatted(date: .abbreviated, time: .standard),
                            badges: videoBadges(for: video),
                            isPlaying: false,
                            playIcon: "play.rectangle.fill",
                            theme: theme,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedVideoIDs.contains(video.id),
                            onPlay: { playVideo(video) },
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
                    title: "暂无录音",
                    message: "在「声控」页启用声控录音后，超过阈值的声音将自动保存在此。",
                    systemImage: "waveform",
                    theme: theme
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedAudioSessions) { session in
                        MediaListCard(
                            fileName: session.fileName,
                            subtitle: nil,
                            detailLine: audioDetailLine(for: session),
                            badges: audioBadges(for: session),
                            isPlaying: audioPlayerController.playingID == session.id,
                            playIcon: audioPlayerController.playingID == session.id ? "stop.circle.fill" : "play.circle.fill",
                            theme: theme,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedAudioIDs.contains(session.id),
                            onPlay: { toggleAudioPlayback(session) },
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
                ProMetricCard(title: "录音数", value: "\(sessions.count)", theme: theme)
                ProMetricCard(title: "总时长", value: formattedAudioTotalDuration, theme: theme)
                ProMetricCard(
                    title: "最高峰值",
                    value: sessions.isEmpty ? "—" : "\(Int(sessions.map(\.peakDB).max() ?? 0))",
                    theme: theme
                )
            case .video:
                ProMetricCard(title: "录像数", value: "\(videoSessions.count)", theme: theme)
                ProMetricCard(title: "总时长", value: formattedVideoTotalDuration, theme: theme)
                ProMetricCard(
                    title: "最高峰值",
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
        var badges = ["峰值 \(Int(video.peakDB)) dB"]
        if let lat = video.latitude, let lon = video.longitude {
            badges.append(String(format: "%.4f, %.4f", lat, lon))
        }
        return badges
    }

    private func audioBadges(for session: RecordingSession) -> [String] {
        var badges = ["峰值 \(Int(session.peakDB)) dB", "均值 \(Int(session.averageDB)) dB"]
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
        audioPlayerController.togglePlayback(
            for: session,
            coexistingWithMonitoring: engine.isMonitoring,
            backgroundMonitoringEnabled: engine.backgroundMonitoringEnabled
        ) {
            restoreMonitoringAudioSession()
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
                session.filePath = url.path
                session.fileHash = RecordingSession.hashFile(at: url.path)
            }
        case .video(let session):
            renameFile(
                session: session,
                newBaseName: trimmed,
                extension: target.fileExtension.isEmpty ? "mp4" : target.fileExtension
            ) { url in
                session.fileName = url.lastPathComponent
                session.filePath = url.path
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
    let subtitle: String?
    var detailLine: String?
    let badges: [String]
    let isPlaying: Bool
    let playIcon: String
    let theme: ModeVisualTheme
    let isSelectionMode: Bool
    let isSelected: Bool
    let onPlay: () -> Void
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

                    FlowBadgeRow(badges: badges, theme: theme)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isSelectionMode {
                    Menu {
                        Button {
                            onRename()
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: onDelete) {
                            Label("删除", systemImage: "trash")
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
            }
        }
        .contextMenu {
            if !isSelectionMode {
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
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
                        Button("完成", action: onDismiss)
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
