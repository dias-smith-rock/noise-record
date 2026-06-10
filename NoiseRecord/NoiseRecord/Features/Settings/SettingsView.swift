import SwiftUI

struct SettingsView: View {
    @Bindable var engine: NoiseMonitorEngine
    @State private var calibrationReference: Float = 94
    @State private var showCalibrationAlert = false
    @State private var calibrationAlertMessage = ""

    @State private var showResetAlert = false
    @State private var resetAlertTitle = ""
    @State private var resetAlertMessage = ""

    @State private var displayedUserAdjustment: Float = DeviceCalibrationStore.userAdjustment
    @State private var displayedTotalOffset: Float = DeviceCalibrationStore.totalOffset

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    var body: some View {
        Form {
            Section {
                EngineModeSwitchView(engine: engine, showsInlineHint: false)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
            } header: {
                Text("测量模式")
            } footer: {
                Text(measurementMode.coreDescription)
            }

            if !engine.isHighSensitivityMode {
                Section {
                    Picker("A/C/Z 计权", selection: Binding(
                        get: { engine.weightingType },
                        set: { engine.updateWeighting($0) }
                    )) {
                        ForEach(WeightingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("高级 · 标准模式计权")
                } footer: {
                    Text("一般用户保持默认 A 计权即可。仅在需要对比 C/Z 计权时使用。")
                }
            }

            Section {
                LabeledContent("当前模式", value: measurementMode.userFacingTitle)
                LabeledContent("技术底标", value: measurementMode.technicalBadge)
                LabeledContent("设备型号", value: DeviceCalibrationStore.deviceModelIdentifier)
                LabeledContent("设备偏移", value: String(format: "%.1f dB", DeviceCalibrationStore.deviceOffset))
                LabeledContent("用户微调", value: String(format: "%+.1f dB", displayedUserAdjustment))
                LabeledContent("总偏移量", value: String(format: "%.1f dB", displayedTotalOffset))
                LabeledContent("RMS 下限", value: String(format: "%.0e", SPLCalculator.rmsFloor))

                VStack(alignment: .leading) {
                    Text("参考声级：\(Int(calibrationReference)) dB")
                    Slider(value: $calibrationReference, in: 60...110, step: 1)
                }

                Button("使用当前读数校准") {
                    let previousAdjustment = DeviceCalibrationStore.userAdjustment
                    DeviceCalibrationStore.calibrate(
                        referenceSPL: calibrationReference,
                        measuredDBFS: engine.lastDBFS
                    )
                    refreshCalibrationDisplay()

                    let newAdjustment = displayedUserAdjustment
                    let delta = newAdjustment - previousAdjustment
                    if abs(delta) < 0.05 {
                        calibrationAlertMessage = """
                        校准已完成，读数微调幅度很小。

                        用户微调：\(formatSignedDB(newAdjustment))
                        总偏移量：\(formatDB(displayedTotalOffset))

                        请继续在监测页观察读数是否符合您的声级计。
                        """
                    } else {
                        calibrationAlertMessage = """
                        已根据 \(Int(calibrationReference)) dB 的参考声级完成校准。

                        用户微调：\(formatSignedDB(previousAdjustment)) → \(formatSignedDB(newAdjustment))
                        总偏移量：\(formatDB(displayedTotalOffset))

                        之后监测页显示的分贝值会按新基准计算。
                        """
                    }
                    showCalibrationAlert = true
                }
                .disabled(!engine.isMonitoring)

                Button("重置校准", role: .destructive) {
                    performResetCalibration()
                }
            } header: {
                Text("设备校准")
            } footer: {
                Text("测量模式偏移基准 115–118 dB，安静房间本底应稳定在 30–40 dB。可配合专业声级计进一步微调。")
            }
        }
        .navigationTitle("设置")
        .onAppear {
            refreshCalibrationDisplay()
        }
        .alert("校准已保存", isPresented: $showCalibrationAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(calibrationAlertMessage)
        }
        .alert(resetAlertTitle, isPresented: $showResetAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(resetAlertMessage)
        }
    }

    private func performResetCalibration() {
        let previousAdjustment = DeviceCalibrationStore.userAdjustment
        let previousTotal = DeviceCalibrationStore.deviceOffset + previousAdjustment
        DeviceCalibrationStore.resetCalibration()
        refreshCalibrationDisplay()

        if abs(previousAdjustment) < 0.05 {
            resetAlertTitle = "当前已是出厂默认"
            resetAlertMessage = """
            您还没有做过手动微调，无需重置。

            用户微调：0 dB（无额外调整）
            总偏移量：\(formatDB(displayedTotalOffset))

            安静房间的分贝读数一般会在 30–40 dB 左右。
            """
        } else {
            resetAlertTitle = "已恢复出厂校准"
            resetAlertMessage = """
            已清除您之前设置的手动微调（\(formatSignedDB(previousAdjustment))）。

            总偏移量：\(formatDB(previousTotal)) → \(formatDB(displayedTotalOffset))
            用户微调：\(formatSignedDB(previousAdjustment)) → 0 dB

            监测页的分贝读数会回到出厂默认水平。若读数仍不准，可重新用声级计校准。
            """
        }
        showResetAlert = true
    }

    private func refreshCalibrationDisplay() {
        displayedUserAdjustment = DeviceCalibrationStore.userAdjustment
        displayedTotalOffset = DeviceCalibrationStore.totalOffset
    }

    private func formatDB(_ value: Float) -> String {
        String(format: "%.1f dB", value)
    }

    private func formatSignedDB(_ value: Float) -> String {
        String(format: "%+.1f dB", value)
    }
}
