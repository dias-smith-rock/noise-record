import SwiftData
import SwiftUI

struct SettingsView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var measurementSamples: [MeasurementSample]

    @State private var calibrationReference: Float = DeviceCalibrationStore.referenceSPL
    @State private var showCalibrationAlert = false
    @State private var calibrationAlertMessage = ""

    @State private var showResetAlert = false
    @State private var resetAlertTitle = ""
    @State private var resetAlertMessage = ""

    @State private var showClearMeasurementsConfirm = false
    @State private var showClearMeasurementsDone = false

    @State private var displayedUserAdjustment: Float = DeviceCalibrationStore.userAdjustment
    @State private var displayedTotalOffset: Float = DeviceCalibrationStore.totalOffset

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: L10n.settingsTitle, theme: theme)

            Form {
            Section {
                NavigationLink {
                    LanguagePickerView(appearance: appearance)
                } label: {
                    LabeledContent(L10n.settingsLanguage, value: appearance.preferredLanguage.displayName)
                }

                Picker(L10n.settingsTheme, selection: $appearance.colorSchemePreference) {
                    ForEach(AppColorSchemePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
            } header: {
                Text(L10n.settingsAppearanceHeader)
            }

            Section {
                EngineModeSwitchView(engine: engine, showsInlineHint: false)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
            } header: {
                Text(L10n.settingsMeasurementMode)
            } footer: {
                Text(measurementMode.coreDescription)
            }

            if !engine.isHighSensitivityMode {
                Section {
                    Picker(L10n.settingsWeightingPicker, selection: Binding(
                        get: { engine.weightingType },
                        set: { engine.updateWeighting($0) }
                    )) {
                        ForEach(WeightingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(L10n.settingsWeightingHeader)
                } footer: {
                    Text(L10n.settingsWeightingFooter)
                }
            }

            Section {
                LabeledContent(L10n.settingsCurrentMode, value: measurementMode.userFacingTitle)
                LabeledContent(L10n.settingsTechnicalBadge, value: measurementMode.technicalBadge)
                LabeledContent(L10n.settingsDeviceModel, value: DeviceCalibrationStore.deviceModelIdentifier)
                LabeledContent(L10n.settingsDeviceOffset, value: String(format: "%.1f dB", DeviceCalibrationStore.deviceOffset))
                LabeledContent(L10n.settingsUserAdjustment, value: String(format: "%+.1f dB", displayedUserAdjustment))
                LabeledContent(L10n.settingsTotalOffset, value: String(format: "%.1f dB", displayedTotalOffset))
                LabeledContent(L10n.settingsRmsFloor, value: String(format: "%.0e", SPLCalculator.rmsFloor))

                VStack(alignment: .leading) {
                    Text(L10n.settingsReferenceLevel(Int(calibrationReference)))
                    Slider(value: $calibrationReference, in: 10...140, step: 1)
                }

                Button(L10n.settingsCalibrateButton) {
                    let previousAdjustment = DeviceCalibrationStore.userAdjustment
                    DeviceCalibrationStore.calibrate(
                        referenceSPL: calibrationReference,
                        measuredDBFS: engine.lastDBFS
                    )
                    refreshCalibrationDisplay()

                    let newAdjustment = displayedUserAdjustment
                    let delta = newAdjustment - previousAdjustment
                    if abs(delta) < 0.05 {
                        calibrationAlertMessage = L10n.settingsCalibrationSavedSmall(
                            adjustment: formatSignedDB(newAdjustment),
                            totalOffset: formatDB(displayedTotalOffset)
                        )
                    } else {
                        calibrationAlertMessage = L10n.settingsCalibrationSavedChanged(
                            reference: Int(calibrationReference),
                            previous: formatSignedDB(previousAdjustment),
                            newValue: formatSignedDB(newAdjustment),
                            totalOffset: formatDB(displayedTotalOffset)
                        )
                    }
                    showCalibrationAlert = true
                }
                .disabled(!engine.isMonitoring)

                Button(L10n.settingsResetButton, role: .destructive) {
                    performResetCalibration()
                }
            } header: {
                Text(L10n.settingsCalibrationHeader)
            } footer: {
                Text(L10n.settingsCalibrationFooter)
            }

            Section {
                LabeledContent(L10n.settingsMeasurementSampleCount, value: "\(measurementSamples.count)")
                Button(L10n.settingsClearMeasurements, role: .destructive) {
                    showClearMeasurementsConfirm = true
                }
                .disabled(measurementSamples.isEmpty)
            } header: {
                Text(L10n.settingsDataHeader)
            }

            Section {
                LabeledContent(L10n.settingsVersion, value: appVersionString)
                Link(L10n.settingsPrivacyPolicy, destination: LegalURLs.privacyPolicy)
                Link(L10n.settingsTermsOfService, destination: LegalURLs.termsOfService)
                Link(destination: SupportContact.mailtoURL) {
                    LabeledContent(L10n.settingsSupport, value: SupportContact.email)
                }
            } header: {
                Text(L10n.settingsAboutHeader)
            } footer: {
                Text(L10n.settingsDisclaimerBody)
            }
            }
            .scrollContentBackground(.hidden)
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .onAppear {
            calibrationReference = DeviceCalibrationStore.referenceSPL
            refreshCalibrationDisplay()
        }
        .alert(L10n.settingsCalibrationSavedTitle, isPresented: $showCalibrationAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(calibrationAlertMessage)
        }
        .alert(resetAlertTitle, isPresented: $showResetAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(resetAlertMessage)
        }
        .confirmationDialog(
            L10n.settingsClearMeasurements,
            isPresented: $showClearMeasurementsConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) {
                clearMeasurementHistory()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.settingsClearMeasurementsConfirm)
        }
        .alert(L10n.settingsClearMeasurements, isPresented: $showClearMeasurementsDone) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.settingsClearMeasurementsDone)
        }
    }

    private func clearMeasurementHistory() {
        do {
            try MeasurementDataStore.clearAllSamples(in: modelContext)
            showClearMeasurementsDone = true
        } catch {
            // SwiftData delete rarely fails; ignore for v1.
        }
    }

    private func performResetCalibration() {
        let previousAdjustment = DeviceCalibrationStore.userAdjustment
        let previousTotal = DeviceCalibrationStore.deviceOffset + previousAdjustment
        DeviceCalibrationStore.resetCalibration()
        refreshCalibrationDisplay()

        if abs(previousAdjustment) < 0.05 {
            resetAlertTitle = L10n.settingsResetAlreadyDefaultTitle
            resetAlertMessage = L10n.settingsResetAlreadyDefaultMessage(
                totalOffset: formatDB(displayedTotalOffset)
            )
        } else {
            resetAlertTitle = L10n.settingsResetRestoredTitle
            resetAlertMessage = L10n.settingsResetRestoredMessage(
                previous: formatSignedDB(previousAdjustment),
                previousTotal: formatDB(previousTotal),
                newTotal: formatDB(displayedTotalOffset),
                previousAdjustment: formatSignedDB(previousAdjustment)
            )
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
