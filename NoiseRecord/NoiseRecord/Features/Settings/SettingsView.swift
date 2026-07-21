import CoreLocation
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    let isTabActive: Bool

    @State private var measurementSampleCount = 0

    @State private var calibrationReference: Float = DeviceCalibrationStore.defaultReferenceSPL
    @State private var showCalibrationAlert = false
    @State private var calibrationAlertMessage = ""

    @State private var showResetAlert = false
    @State private var resetAlertTitle = ""
    @State private var resetAlertMessage = ""

    @State private var showClearMeasurementsConfirm = false
    @State private var showClearMeasurementsDone = false

    @State private var displayedUserAdjustment: Float = DeviceCalibrationStore.userAdjustment
    @State private var displayedTotalOffset: Float = DeviceCalibrationStore.totalOffset
    @State private var waveformReferenceLimit: Float = NoiseReferenceLimits.residentialNightDB
    @State private var showAppReviewPrompt = false
    @State private var showsPrivacyChoices = false
    @State private var wakeReminderTime = SleepMonitorSettingsStore.defaultWakeDate
    @State private var locationAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var showLocationAccessGuide = false
    @State private var showLanguageDebugSheet = false
    @State private var showAccentDebugSheet = false

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

    private var locationAuthorizationSummary: String {
        switch locationAuthorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return L10n.settingsLocationAccessStatusAllowed
        case .denied, .restricted:
            return L10n.settingsLocationAccessStatusDenied
        case .notDetermined:
            return L10n.settingsLocationAccessStatusNotSet
        @unknown default:
            return L10n.settingsLocationAccessStatusNotSet
        }
    }

    private var shouldShowLocationAccessGuide: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        switch locationAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
        #endif
    }

    var body: some View {
        let _ = appearance.languageRefreshID
        let _ = appearance.accentRefreshID

        VStack(spacing: 0) {
            ProTabHeader(title: L10n.settingsTitle, theme: theme)

            RemoveAdsSettingsPromo(theme: theme)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .id(appearance.languageRefreshID)

            ScrollView {
                VStack(spacing: 20) {
                    appearanceSettingsSection
                    monitoringSettingsSection
                    sleepSettingsSection
                    calibrationSettingsSection
                    dataSettingsSection
                    aboutSettingsSection
                    #if DEBUG
                    debugSettingsSection
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .id(appearance.languageRefreshID)
        }
        .observesAppLanguage()
        .debugView("tab.settings")
        .debugAction("settings.open_paywall") {
            PaywallPresenter.shared.present(context: .settings)
        }
        .debugAction("settings.open_language") {
            showLanguageDebugSheet = true
        }
        .debugAction("settings.open_accent") {
            showAccentDebugSheet = true
        }
        .sheet(isPresented: $showLanguageDebugSheet) {
            NavigationStack {
                LanguagePickerView(appearance: appearance)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.close) { showLanguageDebugSheet = false }
                        }
                    }
            }
            .debugView("settings.language")
            .debugPresentation("settings.language") {
                showLanguageDebugSheet = false
            }
        }
        .sheet(isPresented: $showAccentDebugSheet) {
            NavigationStack {
                AccentColorSettingsView(appearance: appearance)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.close) { showAccentDebugSheet = false }
                        }
                    }
            }
            .debugView("settings.accent")
            .debugPresentation("settings.accent") {
                showAccentDebugSheet = false
            }
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .onAppear {
            refreshCalibrationDisplay()
            refreshMeasurementSampleCount()
            refreshPrivacyChoicesVisibility()
            refreshLocationAuthorizationStatus()
            waveformReferenceLimit = NoiseReferenceLimits.residentialNightDB
        }
        .onChange(of: waveformReferenceLimit) { _, newValue in
            NoiseReferenceLimits.residentialNightDB = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: NoiseReferenceLimits.didChangeNotification)) { _ in
            waveformReferenceLimit = NoiseReferenceLimits.residentialNightDB
        }
        .onChange(of: isTabActive) { _, isActive in
            if isActive {
                refreshCalibrationDisplay()
                refreshMeasurementSampleCount()
                refreshPrivacyChoicesVisibility()
                refreshLocationAuthorizationStatus()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isTabActive {
                refreshCalibrationDisplay()
                refreshLocationAuthorizationStatus()
            }
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
                AppTelemetry.logProductEvent("settings_clear_measurements_tap")
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
        .alert(L10n.settingsReviewPromptTitle, isPresented: $showAppReviewPrompt) {
            Button(L10n.settingsReviewAction) {
                AppTelemetry.logProductEvent("settings_review_tap")
                AppReviewPresenter.openAppStoreReviewPage()
            }
            Button(L10n.appReviewLater, role: .cancel) {}
        } message: {
            Text(L10n.settingsReviewPromptMessage)
        }
        .sheet(isPresented: $showLocationAccessGuide) {
            LocationAccessGuideSheet()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var appearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProSectionHeader(title: L10n.settingsAppearanceHeader, theme: theme)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    SettingsNavigationRow(
                        title: L10n.settingsLanguage,
                        value: appearance.preferredLanguage.displayName
                    ) {
                        LanguagePickerView(appearance: appearance)
                    }

                    SettingsDivider(theme: theme)

                    SettingsInlineRow(title: L10n.settingsTheme) {
                        Picker(L10n.settingsTheme, selection: $appearance.colorSchemePreference) {
                            ForEach(AppColorSchemePreference.allCases) { preference in
                                Text(preference.title).tag(preference)
                            }
                        }
                        .labelsHidden()
                    }

                    SettingsDivider(theme: theme)

                    SettingsNavigationRow(
                        title: L10n.settingsAccentColor,
                        value: appearance.accentSummary
                    ) {
                        AccentColorSettingsView(appearance: appearance)
                    }

                    SettingsDivider(theme: theme)

                    SettingsCompoundRow {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.settingsTemperatureUnit)
                                .font(.subheadline)
                            Picker(L10n.settingsTemperatureUnit, selection: $appearance.temperatureUnitPreference) {
                                ForEach(TemperatureUnitPreference.allCases) { unit in
                                    Text(unit.displayName).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }

            SettingsSectionFooter(texts: [
                L10n.settingsAccentColorFooter,
                L10n.settingsTemperatureFooter
            ])
        }
    }

    @ViewBuilder
    private var monitoringSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProSectionHeader(title: L10n.settingsMonitoringHeader, theme: theme)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    ProToggleRow(
                        title: L10n.settingsAutoStartMonitoringTitle,
                        subtitle: L10n.settingsAutoStartMonitoringSubtitle,
                        isOn: Binding(
                            get: { MonitorSettingsStore.autoStartMonitoringOnLaunch },
                            set: { MonitorSettingsStore.autoStartMonitoringOnLaunch = $0 }
                        ),
                        theme: theme,
                        icon: "waveform.circle.fill"
                    )
                    .settingsCardRowPadding()

                    SettingsDivider(theme: theme)

                    SettingsActionRow(
                        title: L10n.settingsLocationAccess,
                        value: locationAuthorizationSummary,
                        action: handleLocationAccessTapped
                    )
                }
            }

            if !engine.isHighSensitivityMode {
                ProCard(theme: theme) {
                    SettingsCompoundRow {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.settingsWeightingPicker)
                                .font(.subheadline)
                            Picker(L10n.settingsWeightingPicker, selection: Binding(
                                get: { engine.weightingType },
                                set: { engine.updateWeighting($0) }
                            )) {
                                ForEach(WeightingType.allCases, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }

            ProCard(theme: theme) {
                SettingsCompoundRow {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(L10n.settingsWaveformReferenceLimit)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(waveformReferenceLimit)) dB")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: $waveformReferenceLimit,
                            in: NoiseReferenceLimits.configurableMinDB...NoiseReferenceLimits.configurableMaxDB,
                            step: 1
                        )
                        .tint(theme.accent)
                        Button(L10n.settingsWaveformReferenceReset) {
                            NoiseReferenceLimits.resetResidentialNightReference()
                            waveformReferenceLimit = NoiseReferenceLimits.residentialNightDB
                        }
                        .font(.subheadline)
                    }
                }
            }

            SettingsSectionFooter(texts: monitoringSectionFooterTexts)
        }
    }

    private var monitoringSectionFooterTexts: [String] {
        var texts = [
            L10n.settingsAutoStartMonitoringFooter,
            L10n.settingsLocationAccessFooter
        ]
        if !engine.isHighSensitivityMode {
            texts.append(L10n.settingsWeightingFooter)
        }
        texts.append(L10n.settingsWaveformReferenceFooter)
        return texts
    }

    @ViewBuilder
    private var sleepSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProSectionHeader(title: L10n.sleepSettingsHeader, theme: theme)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    SettingsCompoundRow {
                        DatePicker(
                            L10n.sleepSettingsWakeTime,
                            selection: $wakeReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: wakeReminderTime) { _, newValue in
                            applyWakeReminderTime(newValue)
                        }
                    }

                    SettingsDivider(theme: theme)

                    SettingsInlineRow(title: L10n.sleepSettingsNotifications) {
                        Toggle(L10n.sleepSettingsNotifications, isOn: Binding(
                            get: { SleepMonitorSettingsStore.notificationsEnabled },
                            set: { newValue in
                                SleepMonitorSettingsStore.notificationsEnabled = newValue
                                Task { await SleepNotificationScheduler.scheduleDailyReminders() }
                            }
                        ))
                        .labelsHidden()
                        .tint(theme.accent)
                    }

                    SettingsDivider(theme: theme)

                    SettingsNavigationRow(title: L10n.sleepReportViewHistory) {
                        SleepHistoryView(measurementMode: measurementMode)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var calibrationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProSectionHeader(title: L10n.settingsCalibrationHeader, theme: theme)

            EngineModeSwitchView(engine: engine)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    SettingsValueRow(title: L10n.settingsDeviceModel, value: HardwareIdentifier.marketingName)
                    SettingsDivider(theme: theme)
                    SettingsValueRow(
                        title: L10n.settingsDeviceOffset,
                        value: String(format: "%.1f dB", DeviceCalibrationStore.deviceOffset)
                    )
                    SettingsDivider(theme: theme)
                    SettingsValueRow(
                        title: L10n.settingsUserAdjustment,
                        value: String(format: "%+.1f dB", displayedUserAdjustment)
                    )
                    SettingsDivider(theme: theme)
                    SettingsValueRow(
                        title: L10n.settingsTotalOffset,
                        value: String(format: "%.1f dB", displayedTotalOffset)
                    )
                    SettingsDivider(theme: theme)
                    SettingsValueRow(
                        title: L10n.settingsRmsFloor,
                        value: String(format: "%.0e", SPLCalculator.rmsFloor)
                    )
                }
            }

            ProCard(theme: theme) {
                SettingsCompoundRow {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.settingsReferenceLevel(Int(calibrationReference)))
                                .font(.subheadline)
                            Slider(value: $calibrationReference, in: 10...140, step: 1)
                                .tint(theme.accent)
                        }

                        Button(L10n.settingsCalibrateButton) {
                            let previousAdjustment = DeviceCalibrationStore.userAdjustment
                            DeviceCalibrationStore.calibrate(
                                referenceSPL: calibrationReference,
                                displayedSPL: engine.currentDB
                            )
                            engine.refreshCalibrationOffset()
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
                            AppTelemetry.logProductEvent("calibration_updated")
                        }
                        .disabled(!engine.isMonitoring)

                        Button(L10n.settingsResetButton, role: .destructive) {
                            performResetCalibration()
                        }
                    }
                }
            }

            SettingsSectionFooter(texts: [L10n.settingsCalibrationFooter])
        }
    }

    @ViewBuilder
    private var dataSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProSectionHeader(title: L10n.settingsDataHeader, theme: theme)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    SettingsValueRow(
                        title: L10n.settingsMeasurementSampleCount,
                        value: "\(measurementSampleCount)"
                    )

                    SettingsDivider(theme: theme)

                    SettingsButtonRow(
                        title: L10n.settingsClearMeasurements,
                        role: .destructive
                    ) {
                        showClearMeasurementsConfirm = true
                    }
                    .disabled(measurementSampleCount == 0)
                }
            }
        }
    }

    @ViewBuilder
    private var aboutSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProSectionHeader(title: L10n.settingsAboutHeader, theme: theme)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    SettingsButtonRow(
                        title: L10n.settingsReviewApp,
                        systemImage: "text.bubble"
                    ) {
                        showAppReviewPrompt = true
                    }

                    SettingsDivider(theme: theme)

                    SettingsLinkRow(
                        title: L10n.settingsPrivacyPolicy,
                        url: LegalURLs.privacyPolicy
                    )

                    if showsPrivacyChoices {
                        SettingsDivider(theme: theme)

                        SettingsButtonRow(
                            title: L10n.settingsPrivacyChoices,
                            systemImage: "hand.raised"
                        ) {
                            AppTelemetry.logProductEvent("settings_privacy_options_tap")
                            Task {
                                try? await AdConsentManager.presentPrivacyOptions()
                                refreshPrivacyChoicesVisibility()
                            }
                        }
                    }

                    SettingsDivider(theme: theme)

                    SettingsLinkRow(
                        title: L10n.settingsTermsOfService,
                        url: LegalURLs.termsOfService
                    )

                    SettingsDivider(theme: theme)

                    SettingsLinkRow(
                        title: L10n.settingsSupport,
                        value: SupportContact.email,
                        url: SupportContact.mailtoURL
                    )

                    SettingsDivider(theme: theme)

                    SettingsValueRow(title: L10n.settingsVersion, value: appVersionString)
                }
            }

            SettingsSectionFooter(texts: [L10n.settingsDisclaimerBody])
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProSectionHeader(title: "Debug", theme: theme)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    SettingsButtonRow(title: "插入 Mock 睡眠数据（7 晚）") {
                        _ = SleepDebugMockData.seedMockSessions(in: modelContext)
                    }

                    SettingsDivider(theme: theme)

                    SettingsButtonRow(title: "清除睡眠数据", role: .destructive) {
                        SleepDebugMockData.clearAllSleepSessions(in: modelContext)
                    }
                }
            }

            SettingsSectionFooter(texts: [
                "模拟器首次启动且无睡眠记录时会自动注入。真机 Debug 可加 Launch Argument：-SeedSleepMockData"
            ])
        }
    }
    #endif

    // MARK: - Actions

    private func handleLocationAccessTapped() {
        if shouldShowLocationAccessGuide {
            showLocationAccessGuide = true
        } else {
            PermissionSettings.openLocationAccessSettings()
        }
    }

    private func clearMeasurementHistory() {
        do {
            try MeasurementDataStore.clearAllSamples(in: modelContext)
            refreshMeasurementSampleCount()
            showClearMeasurementsDone = true
        } catch {
            // SwiftData delete rarely fails; ignore for v1.
        }
    }

    private func performResetCalibration() {
        let previousAdjustment = DeviceCalibrationStore.userAdjustment
        let previousTotal = DeviceCalibrationStore.deviceOffset + previousAdjustment
        DeviceCalibrationStore.resetCalibration()
        engine.refreshCalibrationOffset()
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
        if abs(previousAdjustment) >= 0.05 {
            AppTelemetry.logProductEvent("calibration_reset")
        }
    }

    private func refreshMeasurementSampleCount() {
        measurementSampleCount = MeasurementDataStore.sampleCount(in: modelContext)
    }

    private func refreshCalibrationDisplay() {
        calibrationReference = DeviceCalibrationStore.referenceSPL
        displayedUserAdjustment = DeviceCalibrationStore.userAdjustment
        displayedTotalOffset = DeviceCalibrationStore.totalOffset
    }

    private func refreshPrivacyChoicesVisibility() {
        showsPrivacyChoices = AdMobConfig.adsEnabled && AdConsentManager.isPrivacyOptionsRequired
    }

    private func refreshLocationAuthorizationStatus() {
        locationAuthorizationStatus = CLLocationManager().authorizationStatus
    }

    private func formatDB(_ value: Float) -> String {
        String(format: "%.1f dB", value)
    }

    private func formatSignedDB(_ value: Float) -> String {
        String(format: "%+.1f dB", value)
    }

    private func applyWakeReminderTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        SleepMonitorSettingsStore.wakeHour = components.hour ?? 7
        SleepMonitorSettingsStore.wakeMinute = components.minute ?? 0
        Task { await SleepNotificationScheduler.scheduleDailyReminders() }
    }
}
