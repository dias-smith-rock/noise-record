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
            ProTabHeader(title: "声控录音", theme: theme)

            ScrollView {
                VStack(spacing: 20) {
                    statusHero

                ProCard(theme: theme) {
                    ProToggleRow(
                        title: "启用声控录音",
                        subtitle: "超过开启阈值自动录音，低于停止阈值并延迟后结束。",
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
                        title: "后台持续监测",
                        subtitle: "App 退到后台仍可监测与录音，会增加电量消耗。",
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
                    title: "开启阈值",
                    value: "\(Int(engine.highThreshold))",
                    theme: theme
                )
                ProMetricCard(
                    title: "停止阈值",
                    value: "\(Int(engine.lowThreshold))",
                    theme: theme
                )
                ProMetricCard(
                    title: "当前分贝",
                    value: String(format: "%.0f", engine.currentDB),
                    theme: theme
                )
            }

            if engine.voiceActivatedEnabled {
                ProRecordingStatusBadge(state: engine.recordingState, theme: theme)
            } else {
                Text("声控录音未启用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thresholdCard: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 18) {
                ProSectionHeader(
                    title: "阈值设置",
                    subtitle: "建议停止阈值比开启阈值低 5–10 dB，避免频繁开关",
                    theme: theme
                )

                ProSliderRow(
                    title: "开启阈值",
                    value: $engine.highThreshold,
                    range: 30...90,
                    step: 1,
                    theme: theme
                )
                .onChange(of: engine.highThreshold) { _, _ in engine.persistSettings() }

                ProSliderRow(
                    title: "停止阈值",
                    value: $engine.lowThreshold,
                    range: 20...80,
                    step: 1,
                    theme: theme
                )
                .onChange(of: engine.lowThreshold) { _, _ in engine.persistSettings() }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(theme.accent)
                    Text("阈值基于当前测量模式（\(measurementMode.segmentLabel)）的分贝读数。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aiCard: some View {
        ProCard(theme: theme) {
            ProToggleRow(
                title: "AI 噪音分类",
                subtitle: "识别施工、犬吠、交通等声音，可仅录制目标噪音。",
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
                    title: "仅录制以下类型",
                    subtitle: "不选择则录制全部超阈值声音",
                    theme: theme
                )

                FlowLayout(spacing: 8) {
                    ForEach(aiLabelOptions, id: \.self) { label in
                        Button {
                            toggleAILabel(label)
                        } label: {
                            ProChip(
                                text: localizedAILabel(label),
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
        Text("声控录音文件保存在「录音」标签页，支持播放与 CSV 导出。")
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

    private func localizedAILabel(_ label: String) -> String {
        switch label {
        case "speech": "说话"
        case "music": "音乐"
        case "dog": "犬吠"
        case "cat": "猫叫"
        case "car": "汽车"
        case "engine": "引擎"
        case "drill": "电钻"
        case "hammer": "敲击"
        case "alarm": "警报"
        case "siren": "鸣笛"
        case "applause": "掌声"
        case "laughter": "笑声"
        default: label
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
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
