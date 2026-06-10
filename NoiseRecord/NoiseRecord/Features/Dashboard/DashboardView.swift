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
    @State private var showStopRecordingPrompt = false

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: L10n.dashboardTitle, theme: theme)

            ScrollView {
                VStack(spacing: 20) {
                    EngineModeSwitchView(engine: engine)

                    NoiseLevelGauge(db: engine.currentDB, mode: measurementMode)

                    HStack(spacing: 12) {
                        StatCard(title: L10n.dashboardMax, value: engine.maxDB, theme: theme)
                        StatCard(title: L10n.dashboardMin, value: engine.minDB, theme: theme)
                        StatCard(title: L10n.dashboardAvg, value: engine.averageDB, theme: theme)
                        StatCard(title: L10n.dashboardLeq, value: engine.leq, theme: theme)
                    }

                    if engine.voiceActivatedEnabled {
                        ProRecordingStatusBadge(state: engine.recordingState, theme: theme)
                    }

                    if let label = engine.latestNoiseLabel, engine.aiClassificationEnabled {
                        HStack {
                            Image(systemName: "waveform.badge.magnifyingglass")
                            Text(L10n.dashboardDetected(label, confidence: Int(engine.latestNoiseConfidence * 100)))
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.dashboardWaveform)
                                .font(.headline)
                            if measurementMode.isHighSensitivity {
                                Text(L10n.dashboardFullBand)
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
                        Text(L10n.dashboardSpectrum)
                            .font(.headline)
                        SpectrumView(spectrum: engine.latestSpectrum, mode: measurementMode)
                            .frame(height: 100)
                    }

                    Text(footerNote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button(L10n.dashboardReport) {
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

                        Button(L10n.dashboardExportCSV) {
                            exportCSV()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProFloatingActionButton(
                title: engine.isMonitoring ? L10n.dashboardStop : L10n.dashboardStart,
                systemImage: engine.isMonitoring ? "stop.circle.fill" : "play.circle.fill",
                theme: theme,
                isDestructive: engine.isMonitoring
            ) {
                Task {
                    if engine.isMonitoring {
                        handleStopMonitoringTapped()
                    } else {
                        await engine.requestPermissionAndStart()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
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
        .alert(L10n.errorTitle, isPresented: .constant(engine.errorMessage != nil)) {
            Button(L10n.ok) { engine.errorMessage = nil }
        } message: {
            Text(engine.errorMessage ?? "")
        }
        .confirmationDialog(
            L10n.dashboardStopPromptTitle,
            isPresented: $showStopRecordingPrompt,
            titleVisibility: .visible
        ) {
            Button(L10n.dashboardStopPromptKeep) {
                finishStopMonitoring(keepRecordings: true)
            }
            Button(L10n.dashboardStopPromptDiscard, role: .destructive) {
                finishStopMonitoring(keepRecordings: false)
            }
            Button(L10n.dashboardStopPromptKeepMonitoring, role: .cancel) {}
        } message: {
            Text(stopRecordingPromptMessage)
        }
    }

    private var stopRecordingPromptMessage: String {
        let count = engine.currentSessionRecordingCount
        if count > 0 {
            return L10n.dashboardStopPromptMultiple(count)
        }
        return L10n.dashboardStopPromptInProgress
    }

    private func handleStopMonitoringTapped() {
        if engine.shouldPromptForRecordingsOnStop {
            showStopRecordingPrompt = true
        } else {
            engine.stopMonitoring()
            engine.clearMonitoringSessionTracking()
        }
    }

    private func finishStopMonitoring(keepRecordings: Bool) {
        if !keepRecordings {
            deleteCurrentSessionRecordings()
            engine.isDiscardingSessionRecordings = true
        }
        engine.stopMonitoring()
        engine.isDiscardingSessionRecordings = false
        engine.clearMonitoringSessionTracking()
    }

    private func deleteCurrentSessionRecordings() {
        let ids = engine.currentSessionRecordingIDs
        guard !ids.isEmpty else { return }

        for id in ids {
            var descriptor = FetchDescriptor<RecordingSession>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            guard let session = try? modelContext.fetch(descriptor).first else { continue }
            try? FileManager.default.removeItem(at: session.fileURL)
            modelContext.delete(session)
        }
        try? modelContext.save()
    }

    private var footerNote: String {
        if measurementMode.isHighSensitivity {
            L10n.dashboardFooterHighSensitivity
        } else {
            L10n.dashboardFooterStandard
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
                .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            .navigationTitle(L10n.silenceReportTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(uiImage: report.renderShareImage()), preview: SharePreview(L10n.silenceReportSharePreview, image: Image(uiImage: report.renderShareImage())))
                }
            }
        }
    }
}
