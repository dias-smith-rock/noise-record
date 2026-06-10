import SwiftUI

struct SettingsView: View {
    @Bindable var engine: NoiseMonitorEngine
    @State private var calibrationReference: Float = 94
    @State private var showCalibrationAlert = false

    var body: some View {
        Form {
            Section {
                Toggle("高灵敏低频模式 (Z计权)", isOn: $engine.isHighSensitivityMode)
            } footer: {
                Text("开启后绕过 A 计权，直接测量原始 PCM，可捕捉远距离低频噪声（空调、管道、远处车流）。")
            }

            Section {
                Picker("计权", selection: Binding(
                    get: { engine.weightingType },
                    set: { engine.updateWeighting($0) }
                )) {
                    ForEach(WeightingType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(engine.isHighSensitivityMode)
            } header: {
                Text("计权类型")
            } footer: {
                Text(engine.isHighSensitivityMode
                     ? "高灵敏模式下固定使用 Z 计权（物理原声）。"
                     : "A 计权适合常规环境；C 计权适合低频共振；Z 计权为无滤波物理声压。")
            }

            Section {
                LabeledContent("设备型号", value: DeviceCalibrationStore.deviceModelIdentifier)
                LabeledContent("设备偏移", value: String(format: "%.1f dB", DeviceCalibrationStore.deviceOffset))
                LabeledContent("用户微调", value: String(format: "%+.1f dB", DeviceCalibrationStore.userAdjustment))
                LabeledContent("总偏移量", value: String(format: "%.1f dB", DeviceCalibrationStore.totalOffset))
                LabeledContent("RMS 下限", value: String(format: "%.0e", SPLCalculator.rmsFloor))

                VStack(alignment: .leading) {
                    Text("参考声级：\(Int(calibrationReference)) dB")
                    Slider(value: $calibrationReference, in: 60...110, step: 1)
                }

                Button("使用当前读数校准") {
                    DeviceCalibrationStore.calibrate(
                        referenceSPL: calibrationReference,
                        measuredDBFS: engine.lastDBFS
                    )
                    showCalibrationAlert = true
                }
                .disabled(!engine.isMonitoring)

                Button("重置校准", role: .destructive) {
                    DeviceCalibrationStore.resetCalibration()
                }
            } header: {
                Text("设备校准")
            } footer: {
                Text("测量模式偏移基准 115–118 dB，安静房间本底应稳定在 30–40 dB。可配合专业声级计进一步微调。")
            }
        }
        .navigationTitle("设置")
        .alert("校准已保存", isPresented: $showCalibrationAlert) {
            Button("确定", role: .cancel) {}
        }
    }

}
