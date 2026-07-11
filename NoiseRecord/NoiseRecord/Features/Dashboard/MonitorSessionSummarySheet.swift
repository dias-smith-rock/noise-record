import SwiftUI

struct MonitorSessionEndSheet: View {
    let monitoringSummary: MonitorSessionSummary?
    let previousSession: StoredMonitorSessionSnapshot?
    let recordingSummary: SessionStopSummary?
    let waveformSamples: [Float]
    let measurementMode: AcousticMeasurementMode
    let theme: ModeVisualTheme
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onViewHistory: () -> Void
    let onStartSleep: () -> Void
    let onDismiss: () -> Void

    private var hasRecordingDecision: Bool {
        recordingSummary != nil
    }

    private var displayDuration: TimeInterval {
        monitoringSummary?.duration ?? recordingSummary?.duration ?? 0
    }

    private var displayMaxDB: Float? {
        if let maxDB = monitoringSummary?.maxDB, maxDB > 0 { return maxDB }
        if let peak = recordingSummary?.deferredEvent.peakDB, peak > 0 { return peak }
        return nil
    }

    private var displayAverageDB: Float? {
        if let avg = monitoringSummary?.averageDB, avg > 0 { return avg }
        if let avg = recordingSummary?.deferredEvent.averageDB, avg > 0 { return avg }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.monitorSessionSummaryTitle)
                        .font(.title3.bold())

                    ProCard(theme: theme) {
                        VStack(alignment: .leading, spacing: 10) {
                            summaryRow(
                                title: L10n.monitorSessionSummaryDuration,
                                value: DurationFormatting.hms(from: displayDuration)
                            )
                            if let maxDB = displayMaxDB {
                                summaryRow(
                                    title: L10n.monitorSessionSummaryMax,
                                    value: String(format: "%.0f dB", maxDB)
                                )
                            }
                            if let averageDB = displayAverageDB {
                                summaryRow(
                                    title: L10n.monitorSessionSummaryAverage,
                                    value: String(format: "%.0f dB", averageDB)
                                )
                            }
                            if let previousSession, previousSession.maxDB > 0 {
                                summaryRow(
                                    title: L10n.monitorSessionSummaryPreviousMax,
                                    value: String(format: "%.0f dB", previousSession.maxDB)
                                )
                            }
                            if let recordingSummary {
                                summaryRow(
                                    title: L10n.monitorSessionEndFileSize,
                                    value: DurationFormatting.fileSize(from: recordingSummary.fileSizeBytes)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let recordingSummary, recordingSummary.autoSavedSegmentCount > 0 {
                        Text(
                            L10n.monitorSessionEndAutoSavedClips(recordingSummary.autoSavedSegmentCount)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if !waveformSamples.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.dashboardWaveform)
                                .font(.subheadline.weight(.semibold))

                            WaveformView(
                                samples: waveformSamples,
                                mode: measurementMode,
                                usesCardChrome: true,
                                showsYAxisLabels: false,
                                showsReferenceLimitLine: false
                            )
                            .frame(height: 88)
                        }
                    }

                    if hasRecordingDecision {
                        recordingActions
                    } else {
                        noRecordingActions
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents(hasRecordingDecision ? [.medium, .large] : [.medium])
        .interactiveDismissDisabled(hasRecordingDecision)
    }

    private var recordingActions: some View {
        HStack(spacing: 12) {
            Button(L10n.dashboardStopPromptDiscard, role: .destructive, action: onDiscard)
                .buttonStyle(.bordered)
                .controlSize(.regular)

            Button(L10n.dashboardStopPromptSave, action: onSave)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(theme.accent)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var noRecordingActions: some View {
        VStack(spacing: 12) {
            Text(L10n.monitorSessionSummaryHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onStartSleep) {
                Label(L10n.monitorSessionSummarySleepCTA, systemImage: "moon.zzz.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(theme.accent)

            Button(action: onViewHistory) {
                Label(L10n.monitorSessionSummaryHistoryCTA, systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button(L10n.close, action: onDismiss)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
    }
}
