import AVFoundation
import SwiftData
import SwiftUI

struct RecordingListView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Query(sort: \RecordingSession.startedAt, order: .reverse) private var sessions: [RecordingSession]
    @Environment(\.modelContext) private var modelContext
    @State private var player: AVAudioPlayer?
    @State private var playingID: UUID?
    @State private var shareURL: URL?
    @State private var showShare = false

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryBar

                if sessions.isEmpty {
                    ProEmptyState(
                        title: "暂无录音",
                        message: "在「声控」页启用声控录音后，超过阈值的声音将自动保存在此，便于回放与取证。",
                        systemImage: "waveform",
                        theme: theme
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(sessions) { session in
                            RecordingCard(
                                session: session,
                                isPlaying: playingID == session.id,
                                theme: theme,
                                onPlay: { togglePlayback(session) },
                                onDelete: { deleteSession(session) }
                            )
                        }
                    }
                }

                Text("录音文件含时间戳与峰值分贝，可导出 CSV 用于记录存档。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .proTabBackground(theme: theme)
        .navigationTitle("录音记录")
        .toolbar {
            if !sessions.isEmpty {
                ToolbarItem(placement: .primaryAction) {
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
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ProShareSheet(items: [shareURL])
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            ProMetricCard(title: "录音数", value: "\(sessions.count)", theme: theme)
            ProMetricCard(
                title: "总时长",
                value: formattedTotalDuration,
                theme: theme
            )
            ProMetricCard(
                title: "最高峰值",
                value: sessions.isEmpty ? "—" : "\(Int(sessions.map(\.peakDB).max() ?? 0))",
                theme: theme
            )
        }
    }

    private var formattedTotalDuration: String {
        let total = sessions.reduce(0) { $0 + $1.duration }
        if total < 60 {
            return "\(Int(total))s"
        }
        return "\(Int(total / 60))m"
    }

    private func togglePlayback(_ session: RecordingSession) {
        if playingID == session.id {
            player?.stop()
            playingID = nil
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: session.fileURL)
            player?.play()
            playingID = session.id
        } catch {
            playingID = nil
        }
    }

    private func deleteSession(_ session: RecordingSession) {
        if playingID == session.id {
            player?.stop()
            playingID = nil
        }
        try? FileManager.default.removeItem(at: session.fileURL)
        modelContext.delete(session)
    }
}

private struct RecordingCard: View {
    let session: RecordingSession
    let isPlaying: Bool
    let theme: ModeVisualTheme
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ProCard(theme: theme) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
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
                    Text(session.fileName)
                        .font(.subheadline.bold())
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(session.startedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                        Spacer()
                        Text("\(Int(session.duration))s")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        peakBadge("峰值 \(Int(session.peakDB)) dB")
                        peakBadge("均值 \(Int(session.averageDB)) dB")
                        if let type = session.noiseType {
                            ProChip(text: type, theme: theme)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func peakBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.badgeBackground)
            .clipShape(Capsule())
    }
}
