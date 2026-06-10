import SwiftUI

struct SettingsView: View {
    @Bindable var engine: NoiseMonitorEngine
    @State private var calibrationReference: Float = 94
    @State private var showCalibrationAlert = false

    var body: some View {
        Form {
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
            } header: {
                Text("计权类型")
            } footer: {
                Text("A 计权适合常规环境；C 计权适合低频共振；Z 计权为无滤波物理声压。")
            }

            Section {
                LabeledContent("设备型号", value: DeviceCalibrationStore.deviceModelIdentifier)
                LabeledContent("查找表偏移", value: String(format: "%.1f dB", DeviceCalibrationStore.lookupOffset))
                LabeledContent("用户偏移", value: userOffsetText)
                LabeledContent("当前总偏移", value: String(format: "%.1f dB", DeviceCalibrationStore.totalOffset))

                VStack(alignment: .leading) {
                    Text("参考声级：\(Int(calibrationReference)) dB")
                    Slider(value: $calibrationReference, in: 60...110, step: 1)
                }

                Button("使用当前读数校准") {
                    let measuredDBFS = engine.currentDB - DeviceCalibrationStore.totalOffset
                    DeviceCalibrationStore.calibrate(referenceSPL: calibrationReference, measuredDBFS: measuredDBFS)
                    showCalibrationAlert = true
                }
                .disabled(!engine.isMonitoring)

                Button("重置校准", role: .destructive) {
                    DeviceCalibrationStore.resetCalibration()
                }
            } header: {
                Text("设备校准")
            } footer: {
                Text("配合专业声级计（如 1kHz @ 94dB）进行一次性校准，可提升绝对读数准确性。")
            }
        }
        .navigationTitle("设置")
        .alert("校准已保存", isPresented: $showCalibrationAlert) {
            Button("确定", role: .cancel) {}
        }
    }

    private var userOffsetText: String {
        if let offset = DeviceCalibrationStore.userOffset {
            String(format: "%.1f dB", offset)
        } else {
            "未设置"
        }
    }
}
