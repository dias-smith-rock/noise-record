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

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: "Settings", theme: theme)

            Form {
            Section {
                EngineModeSwitchView(engine: engine, showsInlineHint: false)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
            } header: {
                Text("Measurement Mode")
            } footer: {
                Text(measurementMode.coreDescription)
            }

            if !engine.isHighSensitivityMode {
                Section {
                    Picker("A/C/Z weighting", selection: Binding(
                        get: { engine.weightingType },
                        set: { engine.updateWeighting($0) }
                    )) {
                        ForEach(WeightingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Advanced · Standard mode weighting")
                } footer: {
                    Text("Most users should keep the default A-weighting. Change only when comparing C/Z curves.")
                }
            }

            Section {
                LabeledContent("Current mode", value: measurementMode.userFacingTitle)
                LabeledContent("Technical badge", value: measurementMode.technicalBadge)
                LabeledContent("Device model", value: DeviceCalibrationStore.deviceModelIdentifier)
                LabeledContent("Device offset", value: String(format: "%.1f dB", DeviceCalibrationStore.deviceOffset))
                LabeledContent("User adjustment", value: String(format: "%+.1f dB", displayedUserAdjustment))
                LabeledContent("Total offset", value: String(format: "%.1f dB", displayedTotalOffset))
                LabeledContent("RMS floor", value: String(format: "%.0e", SPLCalculator.rmsFloor))

                VStack(alignment: .leading) {
                    Text("Reference level: \(Int(calibrationReference)) dB")
                    Slider(value: $calibrationReference, in: 60...110, step: 1)
                }

                Button("Calibrate with current reading") {
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
                        Calibration saved. The adjustment was very small.

                        User adjustment: \(formatSignedDB(newAdjustment))
                        Total offset: \(formatDB(displayedTotalOffset))

                        Keep monitoring and compare against your sound level meter.
                        """
                    } else {
                        calibrationAlertMessage = """
                        Calibrated to reference level \(Int(calibrationReference)) dB.

                        User adjustment: \(formatSignedDB(previousAdjustment)) → \(formatSignedDB(newAdjustment))
                        Total offset: \(formatDB(displayedTotalOffset))

                        Monitor readings will use the new baseline.
                        """
                    }
                    showCalibrationAlert = true
                }
                .disabled(!engine.isMonitoring)

                Button("Reset calibration", role: .destructive) {
                    performResetCalibration()
                }
            } header: {
                Text("Device calibration")
            } footer: {
                Text("Mode offset baseline is 115–118 dB; a quiet room should read about 30–40 dB. Fine-tune with a professional meter if needed.")
            }
            }
            .scrollContentBackground(.hidden)
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .onAppear {
            refreshCalibrationDisplay()
        }
        .alert("Calibration saved", isPresented: $showCalibrationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calibrationAlertMessage)
        }
        .alert(resetAlertTitle, isPresented: $showResetAlert) {
            Button("OK", role: .cancel) {}
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
            resetAlertTitle = "Already at factory default"
            resetAlertMessage = """
            No manual adjustment was set; nothing to reset.

            User adjustment: 0 dB (no extra offset)
            Total offset: \(formatDB(displayedTotalOffset))

            A quiet room should read about 30–40 dB.
            """
        } else {
            resetAlertTitle = "Factory calibration restored"
            resetAlertMessage = """
            Cleared your manual adjustment (\(formatSignedDB(previousAdjustment))).

            Total offset: \(formatDB(previousTotal)) → \(formatDB(displayedTotalOffset))
            User adjustment: \(formatSignedDB(previousAdjustment)) → 0 dB

            Monitor readings return to factory defaults. Recalibrate with a meter if needed.
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
