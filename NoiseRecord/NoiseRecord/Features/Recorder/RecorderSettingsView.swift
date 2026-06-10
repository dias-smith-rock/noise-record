import SwiftUI

struct RecorderSettingsView: View {
    @Bindable var engine: NoiseMonitorEngine

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
            ProTabHeader(title: "Voice Recording", theme: theme)

            ScrollView {
                VStack(spacing: 20) {
                    statusHero

                ProCard(theme: theme) {
                    ProToggleRow(
                        title: "Voice-activated recording",
                        subtitle: "Record when level exceeds the start threshold; stop after falling below the stop threshold and a short delay.",
                        isOn: $engine.voiceActivatedEnabled,
                        theme: theme,
                        icon: "record.circle"
                    )
                    .onChange(of: engine.voiceActivatedEnabled) { _, _ in
                        engine.persistSettings()
                    }
                }

                if engine.voiceActivatedEnabled {
                    thresholdCard
                }

                ProCard(theme: theme) {
                    ProToggleRow(
                        title: "Background monitoring",
                        subtitle: "Automatically starts monitoring before backgrounding; voice recording continues in background. Uses more battery.",
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
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
    }

    private var statusHero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProMetricCard(
                    title: "Start",
                    value: "\(Int(engine.highThreshold))",
                    theme: theme
                )
                ProMetricCard(
                    title: "Stop",
                    value: "\(Int(engine.lowThreshold))",
                    theme: theme
                )
                ProMetricCard(
                    title: "Current dB",
                    value: String(format: "%.0f", engine.currentDB),
                    theme: theme
                )
            }

            if engine.voiceActivatedEnabled {
                ProRecordingStatusBadge(state: engine.recordingState, theme: theme)
            } else {
                Text("Voice recording is off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thresholdCard: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 18) {
                ProSectionHeader(
                    title: "Thresholds",
                    subtitle: "Set stop 5–10 dB below start to avoid rapid on/off",
                    theme: theme
                )

                ProSliderRow(
                    title: "Start threshold",
                    value: $engine.highThreshold,
                    range: 30...90,
                    step: 1,
                    theme: theme
                )
                .onChange(of: engine.highThreshold) { _, _ in engine.persistSettings() }

                ProSliderRow(
                    title: "Stop threshold",
                    value: $engine.lowThreshold,
                    range: 20...80,
                    step: 1,
                    theme: theme
                )
                .onChange(of: engine.lowThreshold) { _, _ in engine.persistSettings() }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(theme.accent)
                    Text("Thresholds use dB readings in the current mode (\(measurementMode.segmentLabel)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aiCard: some View {
        ProCard(theme: theme) {
            ProToggleRow(
                title: "AI noise classification",
                subtitle: "Detect construction, barking, traffic, and more; optionally record only selected types.",
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
                    title: "Record only these types",
                    subtitle: "Leave empty to record all sounds above threshold",
                    theme: theme
                )

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
        Text("Voice recordings are saved in the Files tab under Voice.")
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
        switch label {
        case "speech": "Speech"
        case "music": "Music"
        case "dog": "Dog bark"
        case "cat": "Cat"
        case "car": "Car"
        case "engine": "Engine"
        case "drill": "Drill"
        case "hammer": "Hammer"
        case "alarm": "Alarm"
        case "siren": "Siren"
        case "applause": "Applause"
        case "laughter": "Laughter"
        default: label.capitalized
        }
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
