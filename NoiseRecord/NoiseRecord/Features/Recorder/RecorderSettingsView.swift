import SwiftUI

struct RecorderSettingsView: View {
    @Bindable var engine: NoiseMonitorEngine

    private let aiLabelOptions = [
        "speech", "music", "dog", "cat", "car", "engine",
        "drill", "hammer", "alarm", "siren", "applause", "laughter",
    ]

    var body: some View {
        Form {
            Section {
                Toggle("启用声控录音", isOn: $engine.voiceActivatedEnabled)
                    .onChange(of: engine.voiceActivatedEnabled) { _, _ in
                        engine.persistSettings()
                    }
            } footer: {
                Text("超过开启阈值自动录音，低于停止阈值并延迟后结束。")
            }

            if engine.voiceActivatedEnabled {
                Section("阈值设置") {
                    VStack(alignment: .leading) {
                        Text("开启阈值：\(Int(engine.highThreshold)) dB")
                        Slider(value: $engine.highThreshold, in: 30...90, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("停止阈值：\(Int(engine.lowThreshold)) dB")
                        Slider(value: $engine.lowThreshold, in: 20...80, step: 1)
                    }
                }
                .onChange(of: engine.highThreshold) { _, _ in engine.persistSettings() }
                .onChange(of: engine.lowThreshold) { _, _ in engine.persistSettings() }
            }

            Section {
                Toggle("后台持续监测", isOn: $engine.backgroundMonitoringEnabled)
                    .onChange(of: engine.backgroundMonitoringEnabled) { _, _ in
                        engine.persistSettings()
                    }
            } footer: {
                Text("启用后可在后台继续监测与录音，会增加电量消耗。")
            }

            Section {
                Toggle("AI 噪音分类", isOn: $engine.aiClassificationEnabled)
                    .onChange(of: engine.aiClassificationEnabled) { _, newValue in
                        engine.persistSettings()
                        if engine.isMonitoring {
                            engine.stopMonitoring()
                            Task { await engine.requestPermissionAndStart() }
                        }
                    }
            } footer: {
                Text("使用 SoundAnalysis 识别噪音类型，可配合过滤仅录制目标声音。")
            }

            if engine.aiClassificationEnabled {
                Section("仅录制以下类型（留空则全部录制）") {
                    ForEach(aiLabelOptions, id: \.self) { label in
                        Toggle(label, isOn: Binding(
                            get: { engine.aiFilterLabels.contains(label) },
                            set: { enabled in
                                if enabled {
                                    engine.aiFilterLabels.insert(label)
                                } else {
                                    engine.aiFilterLabels.remove(label)
                                }
                            }
                        ))
                    }
                }
            }
        }
        .navigationTitle("声控录音")
    }
}
