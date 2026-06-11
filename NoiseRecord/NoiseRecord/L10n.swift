import Foundation

/// Centralized localization keys. Strings live in `Localizable.xcstrings`.
/// `nonisolated` keeps string accessors usable outside `@MainActor` (Swift 6 default isolation).
nonisolated enum L10n {
    // MARK: - Common

    static let ok = String(localized: "common.ok")
    static let cancel = String(localized: "common.cancel")
    static let close = String(localized: "common.close")
    static let done = String(localized: "common.done")
    static let save = String(localized: "common.save")
    static let delete = String(localized: "common.delete")
    static let share = String(localized: "common.share")
    static let rename = String(localized: "common.rename")
    static let gotIt = String(localized: "common.gotIt")
    static let errorTitle = String(localized: "alert.error.title")

    // MARK: - Tabs

    static let tabMonitor = String(localized: "tab.monitor")
    static let tabVoice = String(localized: "tab.voice")
    static let tabVideo = String(localized: "tab.video")
    static let tabFiles = String(localized: "tab.files")
    static let tabSettings = String(localized: "tab.settings")

    // MARK: - Dashboard

    static let dashboardTitle = String(localized: "dashboard.title")
    static let dashboardMax = String(localized: "dashboard.stat.max")
    static let dashboardMin = String(localized: "dashboard.stat.min")
    static let dashboardAvg = String(localized: "dashboard.stat.avg")
    static let dashboardLeq = String(localized: "dashboard.stat.leq")
    static let dashboardWaveform = String(localized: "dashboard.waveform.title")
    static let dashboardFullBand = String(localized: "dashboard.waveform.fullBandBadge")
    static let dashboardSpectrum = String(localized: "dashboard.spectrum.title")
    static let dashboardReport = String(localized: "dashboard.button.report")
    static let dashboardExportCSV = String(localized: "dashboard.button.exportCSV")
    static let dashboardStop = String(localized: "dashboard.button.stop")
    static let dashboardStart = String(localized: "dashboard.button.start")
    static let dashboardFooterHighSensitivity = String(localized: "dashboard.footer.highSensitivity")
    static let dashboardFooterStandard = String(localized: "dashboard.footer.standard")
    static let dashboardStopPromptTitle = String(localized: "dashboard.stopPrompt.title")
    static let dashboardStopPromptKeep = String(localized: "dashboard.stopPrompt.keep")
    static let dashboardStopPromptDiscard = String(localized: "dashboard.stopPrompt.discard")
    static let dashboardStopPromptKeepMonitoring = String(localized: "dashboard.stopPrompt.keepMonitoring")
    static let silenceReportTitle = String(localized: "silenceReport.title")
    static let silenceReportSharePreview = String(localized: "silenceReport.header")

    static func dashboardDetected(_ label: String, confidence: Int) -> String {
        String(format: String(localized: "dashboard.detectedNoise"), label, confidence)
    }

    static func dashboardStopPromptMultiple(_ count: Int) -> String {
        String(format: String(localized: "dashboard.stopPrompt.message.multiple"), count)
    }

    static let dashboardStopPromptInProgress = String(localized: "dashboard.stopPrompt.message.inProgress")

    // MARK: - Recording status

    static let recordingVoiceStandby = String(localized: "recordingStatus.voiceStandby")
    static let recordingActive = String(localized: "recordingStatus.recording")
    static let recordingAuto = String(localized: "recordingStatus.autoRecording")
    static let recordingTailDelay = String(localized: "recordingStatus.tailDelay")

    // MARK: - Recorder settings

    static let recorderTitle = String(localized: "recorderSettings.title")
    static let recorderVoiceTitle = String(localized: "recorderSettings.voiceActivated.title")
    static let recorderVoiceSubtitle = String(localized: "recorderSettings.voiceActivated.subtitle")
    static let recorderBackgroundTitle = String(localized: "recorderSettings.backgroundMonitoring.title")
    static let recorderBackgroundSubtitle = String(localized: "recorderSettings.backgroundMonitoring.subtitle")
    static let recorderMetricStart = String(localized: "recorderSettings.metric.start")
    static let recorderMetricStop = String(localized: "recorderSettings.metric.stop")
    static let recorderMetricCurrentDb = String(localized: "recorderSettings.metric.currentDb")
    static let recorderStatusOff = String(localized: "recorderSettings.status.off")
    static let recorderThresholdsTitle = String(localized: "recorderSettings.thresholds.title")
    static let recorderThresholdsSubtitle = String(localized: "recorderSettings.thresholds.subtitle")
    static let recorderThresholdStart = String(localized: "recorderSettings.thresholds.start")
    static let recorderThresholdStop = String(localized: "recorderSettings.thresholds.stop")
    static let recorderAiTitle = String(localized: "recorderSettings.ai.title")
    static let recorderAiSubtitle = String(localized: "recorderSettings.ai.subtitle")
    static let recorderAiFilterTitle = String(localized: "recorderSettings.aiFilter.title")
    static let recorderAiFilterSubtitle = String(localized: "recorderSettings.aiFilter.subtitle")
    static let recorderFooter = String(localized: "recorderSettings.footer")

    static func recorderThresholdModeHint(_ mode: String) -> String {
        String(format: String(localized: "recorderSettings.thresholds.modeHint"), mode)
    }

    // MARK: - Video

    static let videoTitle = String(localized: "video.title")
    static let videoCurrentDb = String(localized: "video.metric.currentDb")
    static let videoClipPeak = String(localized: "video.metric.clipPeak")
    static let videoGPS = String(localized: "video.metric.gps")
    static let videoGpsLocated = String(localized: "video.gps.located")
    static let videoGpsPending = String(localized: "video.gps.pending")
    static let videoAutoMonitoringHint = String(localized: "video.hint.autoMonitoring")
    static let videoStopAndSave = String(localized: "video.button.stopAndSave")
    static let videoStartRecording = String(localized: "video.button.startRecording")
    static let videoWatermarkTitle = String(localized: "video.tips.watermarkTitle")
    static let videoWatermarkBody = String(localized: "video.tips.watermarkBody")
    static let videoMonitoringStartFailed = String(localized: "video.error.monitoringStartFailed")

    static func videoSaved(_ name: String) -> String {
        String(format: String(localized: "video.savedFile"), name)
    }

    // MARK: - Files

    static let filesTitle = String(localized: "files.title")
    static let filesTabVideo = String(localized: "files.tab.video")
    static let filesTabVoice = String(localized: "files.tab.voice")
    static let filesPickerType = String(localized: "files.picker.type")
    static let filesPickerSort = String(localized: "files.picker.sort")
    static let filesSortDateDesc = String(localized: "files.sort.dateDescending")
    static let filesSortDateAsc = String(localized: "files.sort.dateAscending")
    static let filesSortPeakDesc = String(localized: "files.sort.peakDescending")
    static let filesSortPeakAsc = String(localized: "files.sort.peakAscending")
    static let filesSortNameAsc = String(localized: "files.sort.nameAscending")
    static let filesSelect = String(localized: "files.selection.select")
    static let filesSelectAll = String(localized: "files.selection.selectAll")
    static let filesDeselectAll = String(localized: "files.selection.deselectAll")
    static let filesSummaryClips = String(localized: "files.summary.clips")
    static let filesSummaryVideos = String(localized: "files.summary.videos")
    static let filesSummaryDuration = String(localized: "files.summary.duration")
    static let filesSummaryPeak = String(localized: "files.summary.peak")
    static let filesBadgeNew = String(localized: "files.badge.new")
    static let filesEmptyVideoTitle = String(localized: "files.empty.video.title")
    static let filesEmptyVideoMessage = String(localized: "files.empty.video.message")
    static let filesEmptyAudioTitle = String(localized: "files.empty.audio.title")
    static let filesEmptyAudioMessage = String(localized: "files.empty.audio.message")
    static let filesRenameTitle = String(localized: "files.rename.alert.title")
    static let filesRenamePlaceholder = String(localized: "files.rename.field.placeholder")
    static let filesRenameMessage = String(localized: "files.rename.alert.message")
    static let filesPlaybackErrorTitle = String(localized: "files.playback.error.title")

    static func filesSelectedCount(_ count: Int) -> String {
        String(format: String(localized: "files.selection.count"), count)
    }

    static func filesDeleteConfirm(_ count: Int) -> String {
        String(format: String(localized: "files.delete.confirm.title"), count)
    }

    static func filesPeakBadge(_ db: Int) -> String {
        String(format: String(localized: "files.badge.peakDb"), db)
    }

    static func filesAvgBadge(_ db: Int) -> String {
        String(format: String(localized: "files.badge.avgDb"), db)
    }

    static func filesVideoNotFound(_ name: String) -> String {
        String(format: String(localized: "files.error.videoNotFound"), name)
    }

    static func filesAudioNotFound(_ name: String) -> String {
        String(format: String(localized: "files.error.audioNotFound"), name)
    }

    // MARK: - Settings

    static let settingsTitle = String(localized: "settings.title")
    static let settingsMeasurementMode = String(localized: "settings.measurementMode.header")
    static let settingsWeightingHeader = String(localized: "settings.weighting.header")
    static let settingsWeightingFooter = String(localized: "settings.weighting.footer")
    static let settingsWeightingPicker = String(localized: "settings.weighting.picker.label")
    static let settingsCalibrationHeader = String(localized: "settings.calibration.header")
    static let settingsCalibrationFooter = String(localized: "settings.calibration.footer")
    static let settingsCurrentMode = String(localized: "settings.calibration.currentMode")
    static let settingsTechnicalBadge = String(localized: "settings.calibration.technicalBadge")
    static let settingsDeviceModel = String(localized: "settings.calibration.deviceModel")
    static let settingsDeviceOffset = String(localized: "settings.calibration.deviceOffset")
    static let settingsUserAdjustment = String(localized: "settings.calibration.userAdjustment")
    static let settingsTotalOffset = String(localized: "settings.calibration.totalOffset")
    static let settingsRmsFloor = String(localized: "settings.calibration.rmsFloor")
    static let settingsCalibrateButton = String(localized: "settings.calibration.calibrateButton")
    static let settingsResetButton = String(localized: "settings.calibration.resetButton")
    static let settingsCalibrationSavedTitle = String(localized: "settings.calibration.alert.saved.title")
    static let settingsResetAlreadyDefaultTitle = String(localized: "settings.calibration.reset.alert.alreadyDefault.title")
    static let settingsResetRestoredTitle = String(localized: "settings.calibration.reset.alert.restored.title")

    static func settingsReferenceLevel(_ db: Int) -> String {
        String(format: String(localized: "settings.calibration.referenceLevel"), db)
    }

    static func settingsCalibrationSavedSmall(adjustment: String, totalOffset: String) -> String {
        String(format: String(localized: "settings.calibration.alert.saved.small"), adjustment, totalOffset)
    }

    static func settingsCalibrationSavedChanged(reference: Int, previous: String, newValue: String, totalOffset: String) -> String {
        String(format: String(localized: "settings.calibration.alert.saved.changed"), reference, previous, newValue, totalOffset)
    }

    static func settingsResetAlreadyDefaultMessage(totalOffset: String) -> String {
        String(format: String(localized: "settings.calibration.reset.alert.alreadyDefault.message"), totalOffset)
    }

    static func settingsResetRestoredMessage(previous: String, previousTotal: String, newTotal: String, previousAdjustment: String) -> String {
        String(format: String(localized: "settings.calibration.reset.alert.restored.message"), previous, previousTotal, newTotal, previousAdjustment)
    }

    static func filesAudioDetailLine(date: String, duration: Int) -> String {
        String(format: String(localized: "files.audio.detailLine"), date, duration)
    }

    // MARK: - Mode guide

    static let modeGuideTitle = String(localized: "modeGuide.title")
    static let modeGuideWhatDoesItDo = String(localized: "modeGuide.section.whatDoesItDo")
    static let modeGuideDetails = String(localized: "modeGuide.section.details")
    static let modeGuideWhyDifferent = String(localized: "modeGuide.section.whyDifferent")
    static let modeGuideWhichMode = String(localized: "modeGuide.section.whichMode")
    static let modeGuideStandardSummary = String(localized: "modeGuide.comparison.standard.summary")
    static let modeGuideHighSensitivitySummary = String(localized: "modeGuide.comparison.highSensitivity.summary")
    static let modeSwitchTitle = String(localized: "modeSwitch.title")
    static let modeSwitchAccessibility = String(localized: "modeSwitch.accessibility.modeExplanation")
    static let modeSwitchLearnMore = String(localized: "modeSwitch.learnMore")

    // MARK: - Gauge & spectrum

    static let noiseRiskQuiet = String(localized: "noiseRisk.quiet")
    static let noiseRiskModerate = String(localized: "noiseRisk.moderate")
    static let noiseRiskLoud = String(localized: "noiseRisk.loud")
    static let noiseRiskDangerous = String(localized: "noiseRisk.dangerous")
    static let gaugeHighSensitivityHint = String(localized: "gauge.highSensitivity.hint")
    static let spectrumLoading = String(localized: "spectrum.loading")

    // MARK: - Overlay

    static let overlayNoisePrefix = String(localized: "overlay.decibel.prefix")
    static let overlayGpsUnavailable = String(localized: "overlay.gps.unavailable")

    // MARK: - Errors

    static let errorMicPermissionDenied = String(localized: "error.audio.permissionDenied")
    static let errorAudioActivationFailed = String(localized: "error.audio.activationFailed")
    static let errorPlaybackPrepareFailed = String(localized: "error.playback.prepareFailed")
    static let errorPlaybackStartFailed = String(localized: "error.playback.startFailed")
    static let errorVideoCameraUnavailable = String(localized: "error.video.cameraUnavailable")
    static let errorVideoMicUnavailable = String(localized: "error.video.microphoneUnavailable")
    static let errorVideoNotRecording = String(localized: "error.video.notRecording")
    static let errorVideoWriterAddTrackFailed = String(localized: "error.video.writerAddTrackFailed")
    static let errorUnknown = String(localized: "error.unknown")
    static let errorAiClassificationFailed = String(localized: "error.aiClassification.failed")
    static let errorStorageInitTitle = String(localized: "error.storage.init.title")
    static let errorStorageInitRetry = String(localized: "error.storage.init.retry")
    static let permissionOpenSettings = String(localized: "permission.openSettings")
    static let permissionMicrophoneDeniedTitle = String(localized: "permission.microphone.denied.title")
    static let permissionMicrophoneDeniedMessage = String(localized: "permission.microphone.denied.message")
    static let permissionCameraDeniedTitle = String(localized: "permission.camera.denied.title")
    static let permissionCameraDeniedMessage = String(localized: "permission.camera.denied.message")
    static let permissionLocationDeniedTitle = String(localized: "permission.location.denied.title")
    static let permissionLocationDeniedMessage = String(localized: "permission.location.denied.message")
    static let recorderMonitoringRequiredTitle = String(localized: "recorder.monitoringRequired.title")
    static let recorderMonitoringRequiredMessage = String(localized: "recorder.monitoringRequired.message")
    static let recorderMonitoringRequiredStart = String(localized: "recorder.monitoringRequired.start")
    static let recorderThresholdInvalid = String(localized: "recorder.threshold.invalid")
    static let recorderAiFilterEmpty = String(localized: "recorder.aiFilter.empty")
    static let dashboardExportCSVFailed = String(localized: "dashboard.exportCSV.failed")
    static let filesRenameFailed = String(localized: "files.rename.failed")
    static let filesBatchShare = String(localized: "files.batchShare")
    static let filesFileHash = String(localized: "files.fileHash")
    static let filesExportRecordingsCSV = String(localized: "files.exportRecordingsCSV")
    static let filesExportRecordingsCSVFailed = String(localized: "files.exportRecordingsCSV.failed")
    static let settingsAboutHeader = String(localized: "settings.about.header")
    static let settingsVersion = String(localized: "settings.version")
    static let settingsPrivacyPolicy = String(localized: "settings.privacyPolicy")
    static let settingsSupport = String(localized: "settings.support")
    static let settingsDisclaimerTitle = String(localized: "settings.disclaimer.title")
    static let settingsDisclaimerBody = String(localized: "settings.disclaimer.body")
    static let settingsDataHeader = String(localized: "settings.data.header")
    static let settingsMeasurementSampleCount = String(localized: "settings.measurementSampleCount")
    static let settingsClearMeasurements = String(localized: "settings.clearMeasurements")
    static let settingsClearMeasurementsConfirm = String(localized: "settings.clearMeasurements.confirm")
    static let settingsClearMeasurementsDone = String(localized: "settings.clearMeasurements.done")
    static let videoRecBadge = String(localized: "REC")
    static let videoPreviewRecording = String(localized: "video.previewRecording")

    static func errorStorageInitMessage(_ detail: String) -> String {
        String(format: String(localized: "error.storage.init.message"), detail)
    }

    static func errorAudioConfigurationFailed(_ message: String) -> String {
        String(format: String(localized: "error.audio.configurationFailed"), message)
    }

    static func errorEngineStartFailed(_ message: String) -> String {
        String(format: String(localized: "error.engine.startFailed"), message)
    }

    static func errorVideoWriterSetupFailed(_ message: String) -> String {
        String(format: String(localized: "error.video.writerSetupFailed"), message)
    }

    static func errorVideoFinishFailed(_ message: String) -> String {
        String(format: String(localized: "error.video.finishFailed"), message)
    }

    // MARK: - AI labels

    static func aiLabel(_ key: String) -> String {
        String(localized: String.LocalizationValue("aiLabel.\(key)"))
    }
}
