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

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monitoringBar

                EngineModeSwitchView(engine: engine)

                NoiseLevelGauge(db: engine.currentDB, mode: measurementMode)

                HStack(spacing: 12) {
                    StatCard(title: "最大", value: engine.maxDB, theme: theme)
                    StatCard(title: "最小", value: engine.minDB, theme: theme)
                    StatCard(title: "平均", value: engine.averageDB, theme: theme)
                    StatCard(title: "Leq", value: engine.leq, theme: theme)
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
                    HStack {
                        Text("时域波形")
                            .font(.headline)
                        if measurementMode.isHighSensitivity {
                            Text("全频扫描")
                                .font(.caption2.bold())
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.badgeBackground)
                                .clipShape(Capsule())
                        }
                    }
                    WaveformView(samples: engine.history, mode: measurementMode)
                        .frame(height: 120)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("频谱分析")
                        .font(.headline)
                    SpectrumView(spectrum: engine.latestSpectrum, mode: measurementMode)
                        .frame(height: 100)
                }

                Text(footerNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("生成报告") {
                        shareReport = SilenceRatingReport(
                            leq: engine.leq,
                            maxDB: engine.maxDB,
                            minDB: engine.minDB,
                            averageDB: engine.averageDB,
                            weighting: engine.effectiveWeighting
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
        .background(
            LinearGradient(
                colors: [
                    theme.cardTint,
                    Color(.systemBackground),
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
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

    private var footerNote: String {
        if measurementMode.isHighSensitivity {
            "全频高灵敏模式 · 读数通常高于标准听感 · 非认证声级计"
        } else {
            "标准听感模式 · 可对照国家住宅噪音标准 · 非认证声级计"
        }
    }

    private var monitoringBar: some View {
        Button {
            Task {
                if engine.isMonitoring {
                    engine.stopMonitoring()
                } else {
                    await engine.requestPermissionAndStart()
                }
            }
        } label: {
            Label(
                engine.isMonitoring ? "停止监测" : "开始监测",
                systemImage: engine.isMonitoring ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(engine.isMonitoring ? .red : theme.accent)
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
            weighting: engine.effectiveWeighting.rawValue,
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
    var theme: ModeVisualTheme = .theme(for: .standard)

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f", value))
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(theme.accent.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.cardTint)
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
