import AVFoundation
import SwiftData
import SwiftUI

struct RecordingListView: View {
    @Query(sort: \RecordingSession.startedAt, order: .reverse) private var sessions: [RecordingSession]
    @Environment(\.modelContext) private var modelContext
    @State private var player: AVAudioPlayer?
    @State private var playingID: UUID?
    @State private var shareURL: URL?
    @State private var showShare = false

    var body: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "暂无录音",
                    systemImage: "waveform",
                    description: Text("启用声控录音后，超阈值录音将自动保存在此。")
                )
            } else {
                ForEach(sessions) { session in
                    RecordingRow(
                        session: session,
                        isPlaying: playingID == session.id,
                        onPlay: { togglePlayback(session) }
                    )
                }
                .onDelete(perform: deleteSessions)
            }
        }
        .navigationTitle("录音记录")
        .toolbar {
            if !sessions.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("导出 CSV") {
                        shareURL = CSVExporter.exportRecordingSessions(sessions)
                        showShare = true
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
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

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            try? FileManager.default.removeItem(at: session.fileURL)
            modelContext.delete(session)
        }
    }
}

private struct RecordingRow: View {
    let session: RecordingSession
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.fileName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(session.startedAt, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("峰值 \(Int(session.peakDB)) dB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let type = session.noiseType {
                        Text(type)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
