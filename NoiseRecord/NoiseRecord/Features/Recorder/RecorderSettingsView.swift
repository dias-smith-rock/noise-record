import SwiftUI

struct RecorderSettingsView: View {
    @Bindable var engine: NoiseMonitorEngine
    let isTabActive: Bool
    @State private var showAiClassificationError = false
    @State private var cachedCurrentDB: Float = 0
    @State private var cachedRecordingState: RecordingState = .idle

    private let aiLabelOptions = [
        "speech", "music", "dog", "cat", "car", "engine",
        "drill", "hammer", "alarm", "siren", "applause", "laughter",
    ]

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: L10n.recorderTitle, theme: theme)

            ScrollView {
                VStack(spacing: 20) {
                    statusHero

                    if engine.voiceActivatedEnabled && !engine.isMonitoring {
                        monitoringRequiredBanner
                    }

                ProCard(theme: theme) {
                    ProToggleRow(
                        title: L10n.recorderVoiceTitle,
                        subtitle: L10n.recorderVoiceSubtitle,
                        isOn: $engine.voiceActivatedEnabled,
                        theme: theme,
                        icon: "record.circle"
                    )
                    .onChange(of: engine.voiceActivatedEnabled) { _, enabled in
                        engine.persistSettings()
                        if enabled, engine.isMonitoring {
                            engine.restoreMonitoringAfterExternalSession()
                        }
                    }
                }

                if engine.voiceActivatedEnabled {
                    thresholdCard
                }

                ProCard(theme: theme) {
                    ProToggleRow(
                        title: L10n.recorderBackgroundTitle,
                        subtitle: L10n.recorderBackgroundSubtitle,
                        isOn: $engine.backgroundMonitoringEnabled,
                        theme: theme,
                        icon: "moon.fill"
                    )
                    .onChange(of: engine.backgroundMonitoringEnabled) { _, _ in
                        engine.persistSettings()
                    }
                }

                aiCard

                if engine.aiClassificationEnabled {
                    aiFilterCard
                }

                footerNote
                }
                .padding()
            }
        }
        .observesAppLanguage()
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .onAppear { refreshCachedMetrics() }
        .onChange(of: isTabActive) { _, active in
            if active { refreshCachedMetrics() }
        }
        .onChange(of: engine.currentDB) { _, _ in
            guard isTabActive else { return }
            cachedCurrentDB = engine.currentDB
        }
        .onChange(of: engine.recordingState) { _, state in
            guard isTabActive else { return }
            cachedRecordingState = state
        }
        .onChange(of: engine.aiClassificationErrorMessage) { _, message in
            showAiClassificationError = message != nil
        }
        .alert(L10n.errorTitle, isPresented: $showAiClassificationError) {
            Button(L10n.ok, role: .cancel) {
                engine.aiClassificationErrorMessage = nil
            }
        } message: {
            Text(engine.aiClassificationErrorMessage ?? L10n.errorAiClassificationFailed)
        }
    }

    private func refreshCachedMetrics() {
        cachedCurrentDB = engine.currentDB
        cachedRecordingState = engine.recordingState
    }

    private var monitoringRequiredBanner: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.recorderMonitoringRequiredTitle, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.accent)
                Text(L10n.recorderMonitoringRequiredMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.recorderMonitoringRequiredStart) {
                    AdSceneLifecycle.recordFirstInteraction(source: "monitor_start_from_voice")
                    Task { await engine.requestPermissionAndStart() }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
            }
        }
    }

    private var statusHero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProMetricCard(
                    title: L10n.recorderMetricStart,
                    value: "\(Int(engine.highThreshold))",
                    theme: theme
                )
                ProMetricCard(
                    title: L10n.recorderMetricStop,
                    value: "\(Int(engine.lowThreshold))",
                    theme: theme
                )
                ProMetricCard(
                    title: L10n.recorderMetricCurrentDb,
                    value: String(format: "%.0f", cachedCurrentDB),
                    theme: theme
                )
            }

            if engine.voiceActivatedEnabled {
                ProRecordingStatusBadge(state: cachedRecordingState, theme: theme)
            } else {
                Text(L10n.recorderStatusOff)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thresholdCard: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 18) {
                ProSectionHeader(
                    title: L10n.recorderThresholdsTitle,
                    subtitle: L10n.recorderThresholdsSubtitle,
                    theme: theme
                )

                ProSliderRow(
                    title: L10n.recorderThresholdStart,
                    value: $engine.highThreshold,
                    range: 30...90,
                    step: 1,
                    theme: theme
                )
                .onChange(of: engine.highThreshold) { _, _ in engine.persistSettings() }

                ProSliderRow(
                    title: L10n.recorderThresholdStop,
                    value: $engine.lowThreshold,
                    range: 20...80,
                    step: 1,
                    theme: theme
                )
                .onChange(of: engine.lowThreshold) { _, _ in engine.persistSettings() }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(theme.accent)
                    Text(L10n.recorderThresholdModeHint(measurementMode.segmentLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aiCard: some View {
        ProCard(theme: theme) {
            ProToggleRow(
                title: L10n.recorderAiTitle,
                subtitle: L10n.recorderAiSubtitle,
                isOn: $engine.aiClassificationEnabled,
                theme: theme,
                icon: "waveform.badge.magnifyingglass"
            )
            .onChange(of: engine.aiClassificationEnabled) { _, _ in
                engine.persistSettings()
                if engine.isMonitoring {
                    engine.stopMonitoring()
                    Task { await engine.requestPermissionAndStart() }
                }
            }
        }
    }

    private var aiFilterCard: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                ProSectionHeader(
                    title: L10n.recorderAiFilterTitle,
                    subtitle: L10n.recorderAiFilterSubtitle,
                    theme: theme
                )

                if engine.aiFilterLabels.isEmpty {
                    Text(L10n.recorderAiFilterEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                FlowLayout(spacing: 8) {
                    ForEach(aiLabelOptions, id: \.self) { label in
                        Button {
                            toggleAILabel(label)
                        } label: {
                            ProChip(
                                text: displayAILabel(label),
                                theme: theme,
                                isSelected: engine.aiFilterLabels.contains(label)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var footerNote: some View {
        Text(L10n.recorderFooter)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private func toggleAILabel(_ label: String) {
        if engine.aiFilterLabels.contains(label) {
            engine.aiFilterLabels.remove(label)
        } else {
            engine.aiFilterLabels.insert(label)
        }
    }

    private func displayAILabel(_ label: String) -> String {
        L10n.aiLabel(label)
    }
}

/// Simple flow layout for AI label chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
