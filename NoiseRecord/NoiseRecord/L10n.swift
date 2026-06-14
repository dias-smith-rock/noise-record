import Foundation

/// Centralized localization keys. Strings live in `Localizable.xcstrings`.
/// `nonisolated` keeps string accessors usable outside `@MainActor` (Swift 6 default isolation).
nonisolated enum L10n {
    private static func localized(_ key: String.LocalizationValue) -> String {
        AppLocalization.string(key)
    }


    // MARK: - Common

    static var ok: String { localized("common.ok") }
    static var cancel: String { localized("common.cancel") }
    static var close: String { localized("common.close") }
    static var done: String { localized("common.done") }
    static var save: String { localized("common.save") }
    static var delete: String { localized("common.delete") }
    static var share: String { localized("common.share") }
    static var rename: String { localized("common.rename") }
    static var gotIt: String { localized("common.gotIt") }
    static var errorTitle: String { localized("alert.error.title") }

    // MARK: - Tabs

    static var tabMonitor: String { localized("tab.monitor") }
    static var tabVoice: String { localized("tab.voice") }
    static var tabVideo: String { localized("tab.video") }
    static var tabFiles: String { localized("tab.files") }
    static var tabSettings: String { localized("tab.settings") }

    // MARK: - Dashboard

    static var dashboardTitle: String { localized("dashboard.title") }
    static var dashboardMax: String { localized("dashboard.stat.max") }
    static var dashboardMin: String { localized("dashboard.stat.min") }
    static var dashboardAvg: String { localized("dashboard.stat.avg") }
    static var dashboardLeq: String { localized("dashboard.stat.leq") }
    static var dashboardWaveform: String { localized("dashboard.waveform.title") }
    static var dashboardFullBand: String { localized("dashboard.waveform.fullBandBadge") }
    static var dashboardSpectrum: String { localized("dashboard.spectrum.title") }
    static var dashboardReport: String { localized("dashboard.button.report") }
    static var dashboardExportCSV: String { localized("dashboard.button.exportCSV") }
    static var dashboardStop: String { localized("dashboard.button.stop") }
    static var dashboardStart: String { localized("dashboard.button.start") }
    static var dashboardFooterHighSensitivity: String { localized("dashboard.footer.highSensitivity") }
    static var dashboardFooterStandard: String { localized("dashboard.footer.standard") }
    static var dashboardStopPromptTitle: String { localized("dashboard.stopPrompt.title") }
    static var dashboardStopPromptSave: String { localized("dashboard.stopPrompt.keep") }
    static var dashboardStopPromptDiscard: String { localized("dashboard.stopPrompt.discard") }
    static var silenceReportTitle: String { localized("silenceReport.title") }
    static var silenceReportSharePreview: String { localized("silenceReport.header") }

    static func dashboardDetected(_ label: String, confidence: Int) -> String {
        String(format: localized("dashboard.detectedNoise"), label, confidence)
    }

    static func dashboardStopPromptMultiple(_ count: Int) -> String {
        String(format: localized("dashboard.stopPrompt.message.multiple"), count)
    }

    static var dashboardStopPromptInProgress: String { localized("dashboard.stopPrompt.message.inProgress") }

    // MARK: - Recording status

    static var recordingVoiceStandby: String { localized("recordingStatus.voiceStandby") }
    static var recordingActive: String { localized("recordingStatus.recording") }
    static var recordingAuto: String { localized("recordingStatus.autoRecording") }
    static var recordingTailDelay: String { localized("recordingStatus.tailDelay") }

    // MARK: - Recorder settings

    static var recorderTitle: String { localized("recorderSettings.title") }
    static var recorderVoiceTitle: String { localized("recorderSettings.voiceActivated.title") }
    static var recorderVoiceSubtitle: String { localized("recorderSettings.voiceActivated.subtitle") }
    static var recorderBackgroundTitle: String { localized("recorderSettings.backgroundMonitoring.title") }
    static var recorderBackgroundSubtitle: String { localized("recorderSettings.backgroundMonitoring.subtitle") }
    static var recorderMetricStart: String { localized("recorderSettings.metric.start") }
    static var recorderMetricStop: String { localized("recorderSettings.metric.stop") }
    static var recorderMetricCurrentDb: String { localized("recorderSettings.metric.currentDb") }
    static var recorderStatusOff: String { localized("recorderSettings.status.off") }
    static var recorderThresholdsTitle: String { localized("recorderSettings.thresholds.title") }
    static var recorderThresholdsSubtitle: String { localized("recorderSettings.thresholds.subtitle") }
    static var recorderThresholdStart: String { localized("recorderSettings.thresholds.start") }
    static var recorderThresholdStop: String { localized("recorderSettings.thresholds.stop") }
    static var recorderAiTitle: String { localized("recorderSettings.ai.title") }
    static var recorderAiSubtitle: String { localized("recorderSettings.ai.subtitle") }
    static var recorderAiFilterTitle: String { localized("recorderSettings.aiFilter.title") }
    static var recorderAiFilterSubtitle: String { localized("recorderSettings.aiFilter.subtitle") }
    static var recorderFooter: String { localized("recorderSettings.footer") }

    static func recorderThresholdModeHint(_ mode: String) -> String {
        String(format: localized("recorderSettings.thresholds.modeHint"), mode)
    }

    // MARK: - Video

    static var videoTitle: String { localized("video.title") }
    static var videoCurrentDb: String { localized("video.metric.currentDb") }
    static var videoClipPeak: String { localized("video.metric.clipPeak") }
    static var videoGPS: String { localized("video.metric.gps") }
    static var videoGpsLocated: String { localized("video.gps.located") }
    static var videoGpsPending: String { localized("video.gps.pending") }
    static var videoAutoMonitoringHint: String { localized("video.hint.autoMonitoring") }
    static var videoStartRecording: String { localized("video.button.startRecording") }
    static var videoSwitchCamera: String { localized("video.button.switchCamera") }
    static var videoStopAndSave: String { localized("video.button.stopAndSave") }
    static var videoWatermarkTitle: String { localized("video.tips.watermarkTitle") }
    static var videoWatermarkBody: String { localized("video.tips.watermarkBody") }
    static var videoMonitoringStartFailed: String { localized("video.error.monitoringStartFailed") }

    static func videoSaved(_ name: String) -> String {
        String(format: localized("video.savedFile"), name)
    }

    // MARK: - Files

    static var filesTitle: String { localized("files.title") }
    static var filesTabVideo: String { localized("files.tab.video") }
    static var filesTabVoice: String { localized("files.tab.voice") }
    static var filesPickerType: String { localized("files.picker.type") }
    static var filesPickerSort: String { localized("files.picker.sort") }
    static var filesSortDateDesc: String { localized("files.sort.dateDescending") }
    static var filesSortDateAsc: String { localized("files.sort.dateAscending") }
    static var filesSortPeakDesc: String { localized("files.sort.peakDescending") }
    static var filesSortPeakAsc: String { localized("files.sort.peakAscending") }
    static var filesSortNameAsc: String { localized("files.sort.nameAscending") }
    static var filesSelect: String { localized("files.selection.select") }
    static var filesSelectAll: String { localized("files.selection.selectAll") }
    static var filesDeselectAll: String { localized("files.selection.deselectAll") }
    static var filesSummaryClips: String { localized("files.summary.clips") }
    static var filesSummaryVideos: String { localized("files.summary.videos") }
    static var filesSummaryDuration: String { localized("files.summary.duration") }
    static var filesSummaryPeak: String { localized("files.summary.peak") }
    static var filesBadgeNew: String { localized("files.badge.new") }
    static var filesEmptyVideoTitle: String { localized("files.empty.video.title") }
    static var filesEmptyVideoMessage: String { localized("files.empty.video.message") }
    static var filesEmptyAudioTitle: String { localized("files.empty.audio.title") }
    static var filesEmptyAudioMessage: String { localized("files.empty.audio.message") }
    static var filesRenameTitle: String { localized("files.rename.alert.title") }
    static var filesRenamePlaceholder: String { localized("files.rename.field.placeholder") }
    static var filesRenameMessage: String { localized("files.rename.alert.message") }
    static var filesPlaybackErrorTitle: String { localized("files.playback.error.title") }

    static func filesSelectedCount(_ count: Int) -> String {
        String(format: localized("files.selection.count"), count)
    }

    static func filesDeleteConfirm(_ count: Int) -> String {
        String(format: localized("files.delete.confirm.title"), count)
    }

    static func filesPeakBadge(_ db: Int) -> String {
        String(format: localized("files.badge.peakDb"), db)
    }

    static func filesAvgBadge(_ db: Int) -> String {
        String(format: localized("files.badge.avgDb"), db)
    }

    static func filesVideoNotFound(_ name: String) -> String {
        String(format: localized("files.error.videoNotFound"), name)
    }

    static func filesAudioNotFound(_ name: String) -> String {
        String(format: localized("files.error.audioNotFound"), name)
    }

    // MARK: - Settings

    static var settingsTitle: String { localized("settings.title") }
    static var settingsMeasurementMode: String { localized("settings.measurementMode.header") }
    static var settingsWeightingHeader: String { localized("settings.weighting.header") }
    static var settingsWeightingFooter: String { localized("settings.weighting.footer") }
    static var settingsWeightingPicker: String { localized("settings.weighting.picker.label") }
    static var settingsCalibrationHeader: String { localized("settings.calibration.header") }
    static var settingsCalibrationFooter: String { localized("settings.calibration.footer") }
    static var settingsCurrentMode: String { localized("settings.calibration.currentMode") }
    static var settingsTechnicalBadge: String { localized("settings.calibration.technicalBadge") }
    static var settingsDeviceModel: String { localized("settings.calibration.deviceModel") }
    static var settingsDeviceOffset: String { localized("settings.calibration.deviceOffset") }
    static var settingsUserAdjustment: String { localized("settings.calibration.userAdjustment") }
    static var settingsTotalOffset: String { localized("settings.calibration.totalOffset") }
    static var settingsRmsFloor: String { localized("settings.calibration.rmsFloor") }
    static var settingsCalibrateButton: String { localized("settings.calibration.calibrateButton") }
    static var settingsResetButton: String { localized("settings.calibration.resetButton") }
    static var settingsCalibrationSavedTitle: String { localized("settings.calibration.alert.saved.title") }
    static var settingsResetAlreadyDefaultTitle: String { localized("settings.calibration.reset.alert.alreadyDefault.title") }
    static var settingsResetRestoredTitle: String { localized("settings.calibration.reset.alert.restored.title") }

    static func settingsReferenceLevel(_ db: Int) -> String {
        String(format: localized("settings.calibration.referenceLevel"), db)
    }

    static func settingsCalibrationSavedSmall(adjustment: String, totalOffset: String) -> String {
        String(format: localized("settings.calibration.alert.saved.small"), adjustment, totalOffset)
    }

    static func settingsCalibrationSavedChanged(reference: Int, previous: String, newValue: String, totalOffset: String) -> String {
        String(format: localized("settings.calibration.alert.saved.changed"), reference, previous, newValue, totalOffset)
    }

    static func settingsResetAlreadyDefaultMessage(totalOffset: String) -> String {
        String(format: localized("settings.calibration.reset.alert.alreadyDefault.message"), totalOffset)
    }

    static func settingsResetRestoredMessage(previous: String, previousTotal: String, newTotal: String, previousAdjustment: String) -> String {
        String(format: localized("settings.calibration.reset.alert.restored.message"), previous, previousTotal, newTotal, previousAdjustment)
    }

    static func filesAudioDetailLine(date: String, duration: Int) -> String {
        String(format: localized("files.audio.detailLine"), date, duration)
    }

    // MARK: - Mode guide

    static var modeGuideTitle: String { localized("modeGuide.title") }
    static var modeGuideWhatDoesItDo: String { localized("modeGuide.section.whatDoesItDo") }
    static var modeGuideDetails: String { localized("modeGuide.section.details") }
    static var modeGuideWhyDifferent: String { localized("modeGuide.section.whyDifferent") }
    static var modeGuideWhichMode: String { localized("modeGuide.section.whichMode") }
    static var modeGuideStandardSummary: String { localized("modeGuide.comparison.standard.summary") }
    static var modeGuideHighSensitivitySummary: String { localized("modeGuide.comparison.highSensitivity.summary") }
    static var modeSwitchTitle: String { localized("modeSwitch.title") }
    static var modeSwitchAccessibility: String { localized("modeSwitch.accessibility.modeExplanation") }
    static var modeSwitchLearnMore: String { localized("modeSwitch.learnMore") }

    // MARK: - Gauge & spectrum

    static var noiseRiskQuiet: String { localized("noiseRisk.quiet") }
    static var noiseRiskModerate: String { localized("noiseRisk.moderate") }
    static var noiseRiskLoud: String { localized("noiseRisk.loud") }
    static var noiseRiskDangerous: String { localized("noiseRisk.dangerous") }
    static var gaugeHighSensitivityHint: String { localized("gauge.highSensitivity.hint") }
    static var spectrumLoading: String { localized("spectrum.loading") }

    // MARK: - Overlay

    static var overlayNoisePrefix: String { localized("overlay.decibel.prefix") }
    static var overlayTimeLabel: String { localized("overlay.time.label") }
    static var overlayTimeAndLocationLabel: String { localized("overlay.timeAndLocation.label") }
    static var overlayGpsUnavailable: String { localized("overlay.gps.unavailable") }

    static func overlayGpsCoordinates(latitude: Double, longitude: Double) -> String {
        String(format: localized("overlay.gps.coordinates"), latitude, longitude)
    }

    static func overlayDecibelLine(_ decibelString: String) -> String {
        String(format: localized("overlay.decibel.line"), decibelString)
    }

    // MARK: - Errors

    static var errorMicPermissionDenied: String { localized("error.audio.permissionDenied") }
    static var errorAudioActivationFailed: String { localized("error.audio.activationFailed") }
    static var errorPlaybackPrepareFailed: String { localized("error.playback.prepareFailed") }
    static var errorPlaybackStartFailed: String { localized("error.playback.startFailed") }
    static var errorVideoCameraUnavailable: String { localized("error.video.cameraUnavailable") }
    static var errorVideoCannotSwitchCameraWhileRecording: String { localized("error.video.cannotSwitchCameraWhileRecording") }
    static var errorVideoMicUnavailable: String { localized("error.video.microphoneUnavailable") }
    static var errorVideoNotRecording: String { localized("error.video.notRecording") }
    static var errorVideoWriterAddTrackFailed: String { localized("error.video.writerAddTrackFailed") }
    static var errorUnknown: String { localized("error.unknown") }
    static var errorAiClassificationFailed: String { localized("error.aiClassification.failed") }
    static var errorStorageInitTitle: String { localized("error.storage.init.title") }
    static var errorStorageInitRetry: String { localized("error.storage.init.retry") }
    static var permissionOpenSettings: String { localized("permission.openSettings") }
    static var permissionMicrophoneDeniedTitle: String { localized("permission.microphone.denied.title") }
    static var permissionMicrophoneDeniedMessage: String { localized("permission.microphone.denied.message") }
    static var permissionCameraDeniedTitle: String { localized("permission.camera.denied.title") }
    static var permissionCameraDeniedMessage: String { localized("permission.camera.denied.message") }
    static var permissionLocationDeniedTitle: String { localized("permission.location.denied.title") }
    static var permissionLocationDeniedMessage: String { localized("permission.location.denied.message") }
    static var recorderMonitoringRequiredTitle: String { localized("recorder.monitoringRequired.title") }
    static var recorderMonitoringRequiredMessage: String { localized("recorder.monitoringRequired.message") }
    static var recorderMonitoringRequiredStart: String { localized("recorder.monitoringRequired.start") }
    static var recorderThresholdInvalid: String { localized("recorder.threshold.invalid") }
    static var recorderAiFilterEmpty: String { localized("recorder.aiFilter.empty") }
    static var dashboardExportCSVFailed: String { localized("dashboard.exportCSV.failed") }
    static var filesRenameFailed: String { localized("files.rename.failed") }
    static var filesBatchShare: String { localized("files.batchShare") }
    static var filesFileHash: String { localized("files.fileHash") }
    static var filesExportRecordingsCSV: String { localized("files.exportRecordingsCSV") }
    static var filesExportRecordingsCSVFailed: String { localized("files.exportRecordingsCSV.failed") }
    static var settingsAboutHeader: String { localized("settings.about.header") }
    static var settingsReviewApp: String { localized("settings.reviewApp") }
    static var settingsReviewPromptTitle: String { localized("settings.review.prompt.title") }
    static var settingsReviewPromptMessage: String { localized("settings.review.prompt.message") }
    static var settingsReviewAction: String { localized("settings.review.action") }
    static var settingsVersion: String { localized("settings.version") }
    static var appReviewPromptTitle: String { localized("appReview.prompt.title") }
    static var appReviewPromptMessage: String { localized("appReview.prompt.message") }
    static var appReviewRateNow: String { localized("appReview.rateNow") }
    static var appReviewLater: String { localized("appReview.later") }
    static var settingsPrivacyPolicy: String { localized("settings.privacyPolicy") }
    static var settingsTermsOfService: String { localized("settings.termsOfService") }
    static var settingsSupport: String { localized("settings.support") }
    static var settingsDisclaimerTitle: String { localized("settings.disclaimer.title") }
    static var settingsDisclaimerBody: String { localized("settings.disclaimer.body") }
    static var settingsDataHeader: String { localized("settings.data.header") }
    static var settingsMeasurementSampleCount: String { localized("settings.measurementSampleCount") }
    static var settingsClearMeasurements: String { localized("settings.clearMeasurements") }
    static var settingsClearMeasurementsConfirm: String { localized("settings.clearMeasurements.confirm") }
    static var settingsClearMeasurementsDone: String { localized("settings.clearMeasurements.done") }
    static var settingsAppearanceHeader: String { localized("settings.appearance.header") }
    static var settingsLanguage: String { localized("settings.language") }
    static var settingsTheme: String { localized("settings.theme") }
    static var videoRecBadge: String { localized("REC") }
    static var videoPreviewRecording: String { localized("video.previewRecording") }

    static func videoPlaybackSyncedNoise(_ decibel: Float, weighting: String) -> String {
        String(format: localized("video.playback.syncedNoise"), decibel, weighting)
    }

    static var videoPlaybackSyncedHint: String { localized("video.playback.syncedHint") }

    static func errorStorageInitMessage(_ detail: String) -> String {
        String(format: localized("error.storage.init.message"), detail)
    }

    static func errorAudioConfigurationFailed(_ message: String) -> String {
        String(format: localized("error.audio.configurationFailed"), message)
    }

    static func errorEngineStartFailed(_ message: String) -> String {
        String(format: localized("error.engine.startFailed"), message)
    }

    static func errorVideoWriterSetupFailed(_ message: String) -> String {
        String(format: localized("error.video.writerSetupFailed"), message)
    }

    static func errorVideoFinishFailed(_ message: String) -> String {
        String(format: localized("error.video.finishFailed"), message)
    }

    // MARK: - AI labels

    static func aiLabel(_ key: String) -> String {
        AppLocalization.string(String.LocalizationValue("aiLabel.\(key)"))
    }
}
