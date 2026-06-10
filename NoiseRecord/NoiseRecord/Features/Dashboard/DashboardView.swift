import SwiftData
import SwiftUI

struct DashboardView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Environment(\.modelContext) private var modelContext
    @State private var lastSampleTime = Date.distantPast
    @State private var shareReport: SilenceRatingReport?
    @State private var showReportSheet = false
    @State private var csvShareURL: URL?
    @State private var showCSVShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NoiseLevelGauge(db: engine.currentDB)

                HStack(spacing: 12) {
                    StatCard(title: "最大", value: engine.maxDB)
                    StatCard(title: "最小", value: engine.minDB)
                    StatCard(title: "平均", value: engine.averageDB)
                    StatCard(title: "Leq", value: engine.leq)
                }

                if engine.voiceActivatedEnabled {
                    RecordingStatusBadge(state: engine.recordingState)
                }

                if let label = engine.latestNoiseLabel, engine.aiClassificationEnabled {
                    HStack {
                        Image(systemName: "waveform.badge.magnifyingglass")
                        Text("识别：\(label) (\(Int(engine.latestNoiseConfidence * 100))%)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("时域波形")
                        .font(.headline)
                    WaveformView(samples: engine.history)
                        .frame(height: 120)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("频谱分析")
                        .font(.headline)
                    SpectrumView(spectrum: engine.latestSpectrum)
                        .frame(height: 100)
                }

                Text("参考级测量，非认证声级计，仅供参考。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button(engine.isMonitoring ? "停止监测" : "开始监测") {
                        Task {
                            if engine.isMonitoring {
                                engine.stopMonitoring()
                            } else {
                                await engine.requestPermissionAndStart()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("生成报告") {
                        shareReport = SilenceRatingReport(
                            leq: engine.leq,
                            maxDB: engine.maxDB,
                            minDB: engine.minDB,
                            averageDB: engine.averageDB,
                            weighting: engine.weightingType
                        )
                        showReportSheet = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!engine.isMonitoring && engine.leq == 0)

                    Button("导出 CSV") {
                        exportCSV()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("噪音监测")
        .onChange(of: engine.currentDB) { _, _ in
            persistSampleIfNeeded()
        }
        .sheet(isPresented: $showReportSheet) {
            if let report = shareReport {
                ShareReportSheet(report: report)
            }
        }
        .sheet(isPresented: $showCSVShare) {
            if let csvShareURL {
                ShareSheet(items: [csvShareURL])
            }
        }
        .alert("错误", isPresented: .constant(engine.errorMessage != nil)) {
            Button("确定") { engine.errorMessage = nil }
        } message: {
            Text(engine.errorMessage ?? "")
        }
    }

    private func persistSampleIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastSampleTime) >= 1 else { return }
        lastSampleTime = now
        let sample = MeasurementSample(
            timestamp: now,
            dbCurrent: engine.currentDB,
            dbMax: engine.maxDB,
            dbMin: engine.minDB,
            dbAvg: engine.averageDB,
            leq: engine.leq,
            weighting: engine.weightingType.rawValue,
            noiseType: engine.latestNoiseLabel
        )
        modelContext.insert(sample)
    }

    private func exportCSV() {
        let descriptor = FetchDescriptor<MeasurementSample>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let samples = try? modelContext.fetch(descriptor) else { return }
        let rows = samples.map {
            MeasurementCSVRow(
                timestamp: $0.timestamp,
                dbCurrent: $0.dbCurrent,
                dbMax: $0.dbMax,
                dbMin: $0.dbMin,
                dbAvg: $0.dbAvg,
                leq: $0.leq,
                weighting: $0.weighting,
                noiseType: $0.noiseType
            )
        }
        csvShareURL = CSVExporter.exportMeasurementLog(rows: rows)
        showCSVShare = true
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct StatCard: View {
    let title: String
    let value: Float

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f", value))
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct RecordingStatusBadge: View {
    let state: RecordingState

    var body: some View {
        HStack {
            Circle()
                .fill(state == .recording ? .red : (state == .coolingDown ? .orange : .gray))
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private var statusText: String {
        switch state {
        case .idle: "声控待机"
        case .recording: "正在录音"
        case .coolingDown: "尾音延迟中"
        }
    }
}

private struct ShareReportSheet: View {
    let report: SilenceRatingReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(report.summaryText)
                    .font(.body)
                    .padding()
            }
            .navigationTitle("静音评级报告")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(uiImage: report.renderShareImage()), preview: SharePreview("静音报告", image: Image(uiImage: report.renderShareImage())))
                }
            }
        }
    }
}
