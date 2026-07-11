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
    static var noAdsBadge: String { localized("iap.noAdsBadge") }
    static var proBadge: String { localized("iap.proBadge") }
    static var done: String { localized("common.done") }
    static var save: String { localized("common.save") }
    static var delete: String { localized("common.delete") }
    static var share: String { localized("common.share") }
    static var rename: String { localized("common.rename") }
    static var gotIt: String { localized("common.gotIt") }
    static var skip: String { localized("common.skip") }
    static var errorTitle: String { localized("alert.error.title") }

    // MARK: - Tabs

    static var tabMonitor: String { localized("tab.monitor") }
    static var tabVoice: String { localized("tab.voice") }
    static var tabVideo: String { localized("tab.video") }
    static var tabFiles: String { localized("tab.files") }
    static var tabSettings: String { localized("tab.settings") }

    // MARK: - Dashboard

    static var dashboardTitle: String { localized("dashboard.title") }
    static var dashboardFullscreenLED: String { localized("dashboard.fullscreenLED") }
    static var dashboardFullscreenLEDGuide: String { localized("dashboard.fullscreenLED.guide") }
    static func dashboardFullscreenLEDEcoHint(minutes: Int) -> String {
        String(format: localized("dashboard.fullscreenLED.ecoHint"), minutes)
    }
    static var dashboardFullscreenLEDEcoModeLabel: String { localized("dashboard.fullscreenLED.ecoModeLabel") }
    static var dashboardFullscreenLEDEcoModeAccessibilityOn: String {
        localized("dashboard.fullscreenLED.ecoModeAccessibilityOn")
    }
    static var dashboardFullscreenLEDEcoModeAccessibilityOff: String {
        localized("dashboard.fullscreenLED.ecoModeAccessibilityOff")
    }
    static var dashboardMax: String { localized("dashboard.stat.max") }
    static var dashboardMin: String { localized("dashboard.stat.min") }
    static var dashboardAvg: String { localized("dashboard.stat.avg") }
    static var dashboardLeq: String { localized("dashboard.stat.leq") }
    static var dashboardWaveform: String { localized("dashboard.waveform.title") }
    static var dashboardOvernightMonitoringTitle: String { localized("dashboard.overnightMonitoring.title") }
    static var dashboardOvernightMonitoringStartBody: String { localized("dashboard.overnightMonitoring.startBody") }
    static var dashboardOvernightMonitoringReportBody: String { localized("dashboard.overnightMonitoring.reportBody") }
    static var dashboardOvernightMonitoringHistoryBody: String { localized("dashboard.overnightMonitoring.historyBody") }
    static var dashboardOvernightMonitoringActiveTitle: String { localized("dashboard.overnightMonitoring.activeTitle") }

    static func dashboardOvernightMonitoringActiveBody(_ elapsed: String) -> String {
        String(format: localized("dashboard.overnightMonitoring.activeBody"), elapsed)
    }

    static var dashboardFullBand: String { localized("dashboard.waveform.fullBandBadge") }
    static func dashboardWaveformReferenceCaption(limit: Int) -> String {
        String(format: localized("dashboard.waveform.referenceCaption"), limit)
    }
    static var dashboardSpectrum: String { localized("dashboard.spectrum.title") }
    static var dashboardReport: String { localized("dashboard.button.report") }
    static var dashboardExportCSV: String { localized("dashboard.button.exportCSV") }
    static var dashboardStop: String { localized("dashboard.button.stop") }
    static var dashboardStart: String { localized("dashboard.button.start") }
    static var dashboardPlayingPlaceholder: String { localized("dashboard.playing.placeholder") }
    static var dashboardIdleHint: String { localized("dashboard.idle.hint") }
    static var dashboardResumeMonitoring: String { localized("dashboard.idle.resume") }
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
    static var dashboardStopPromptSessionTitle: String { localized("dashboard.stopPrompt.session.title") }

    static func dashboardStopPromptSessionMessage(
        duration: String,
        fileSize: String,
        segmentCount: Int
    ) -> String {
        String(
            format: localized("dashboard.stopPrompt.session.message"),
            duration,
            fileSize,
            segmentCount
        )
    }

    // MARK: - Recording status

    static var recordingVoiceStandby: String { localized("recordingStatus.voiceStandby") }
    static var recordingActive: String { localized("recordingStatus.recording") }
    static var recordingAuto: String { localized("recordingStatus.autoRecording") }
    static var recordingSessionMonitoring: String { localized("recordingStatus.sessionMonitoring") }
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
    static var recorderMetricMonitoring: String { localized("recorderSettings.metric.monitoring") }
    static var recorderStatusOff: String { localized("recorderSettings.status.off") }
    static var recorderStatusOn: String { localized("recorderSettings.status.on") }
    static var recorderSessionRecordingTitle: String { localized("recorderSettings.sessionRecording.title") }
    static var recorderSessionRecordingSubtitle: String { localized("recorderSettings.sessionRecording.subtitle") }
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

    static func videoFreeQuotaHint(remaining: Int, maxDuration: Int) -> String {
        String(format: localized("video.freeQuotaHint"), remaining, maxDuration)
    }

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
    static var settingsMonitoringHeader: String { localized("settings.monitoring.header") }
    static var settingsAutoStartMonitoringTitle: String { localized("settings.autoStartMonitoring.title") }
    static var settingsAutoStartMonitoringSubtitle: String { localized("settings.autoStartMonitoring.subtitle") }
    static var settingsAutoStartMonitoringFooter: String { localized("settings.autoStartMonitoring.footer") }
    static var settingsLocationAccess: String { localized("settings.locationAccess") }
    static var settingsLocationAccessFooter: String { localized("settings.locationAccess.footer") }
    static var settingsLocationAccessStatusAllowed: String { localized("settings.locationAccess.status.allowed") }
    static var settingsLocationAccessStatusDenied: String { localized("settings.locationAccess.status.denied") }
    static var settingsLocationAccessStatusNotSet: String { localized("settings.locationAccess.status.notSet") }
    static var settingsLocationAccessGuideTitle: String { localized("settings.locationAccess.guide.title") }
    static var settingsLocationAccessGuideHeader: String { localized("settings.locationAccess.guide.header") }
    static var settingsLocationAccessGuideStep1: String { localized("settings.locationAccess.guide.step1") }
    static var settingsLocationAccessGuideStep2: String { localized("settings.locationAccess.guide.step2") }
    static var settingsLocationAccessGuideStep3: String { localized("settings.locationAccess.guide.step3") }
    static var settingsLocationAccessGuideFooter: String { localized("settings.locationAccess.guide.footer") }
    static var settingsWeightingHeader: String { localized("settings.weighting.header") }
    static var settingsWeightingFooter: String { localized("settings.weighting.footer") }
    static var settingsWeightingPicker: String { localized("settings.weighting.picker.label") }
    static var settingsWaveformReferenceHeader: String { localized("settings.waveformReference.header") }
    static var settingsWaveformReferenceLimit: String { localized("settings.waveformReference.limit") }
    static var settingsWaveformReferenceReset: String { localized("settings.waveformReference.reset") }
    static var settingsWaveformReferenceFooter: String { localized("settings.waveformReference.footer") }
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

    static func filesAudioDetailLine(date: String, duration: String) -> String {
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
    static var modeSwitchInfoTitle: String { localized("modeSwitch.infoSheet.title") }
    static var modeSwitchInfoStandardTitle: String { localized("modeSwitch.infoSheet.standard.title") }
    static var modeSwitchInfoStandardBody: String { localized("modeSwitch.infoSheet.standard.body") }
    static var modeSwitchInfoHighSensitivityTitle: String { localized("modeSwitch.infoSheet.highSensitivity.title") }
    static var modeSwitchInfoHighSensitivityBody: String { localized("modeSwitch.infoSheet.highSensitivity.body") }

    // MARK: - Gauge & spectrum

    static var noiseRiskQuiet: String { localized("noiseRisk.quiet") }
    static var noiseRiskModerate: String { localized("noiseRisk.moderate") }
    static var noiseRiskLoud: String { localized("noiseRisk.loud") }
    static var noiseRiskDangerous: String { localized("noiseRisk.dangerous") }

    // MARK: - Live Activity

    static var liveActivitySceneWhisper: String { localized("liveActivity.scene.whisper") }
    static var liveActivitySceneConversation: String { localized("liveActivity.scene.conversation") }
    static var liveActivitySceneTraffic: String { localized("liveActivity.scene.traffic") }
    static var liveActivitySceneDrill: String { localized("liveActivity.scene.drill") }
    static var liveActivityStatusMonitoringStandard: String { localized("liveActivity.status.monitoringStandard") }
    static var liveActivityStatusMonitoringHighSensitivity: String { localized("liveActivity.status.monitoringHighSensitivity") }
    static var liveActivityStatusVoiceRecording: String { localized("liveActivity.status.voiceRecording") }
    static var liveActivityStatusVoiceStandby: String { localized("liveActivity.status.voiceStandby") }
    static var liveActivityStatusEnded: String { localized("liveActivity.status.ended") }

    static var gaugeHighSensitivityHint: String { localized("gauge.highSensitivity.hint") }
    static var gaugeAmbientTotalSilence: String { localized("gauge.ambient.totalSilence") }
    static var gaugeAmbientQuietLibrary: String { localized("gauge.ambient.quietLibrary") }
    static var gaugeAmbientNormalConversation: String { localized("gauge.ambient.normalConversation") }
    static var gaugeAmbientCityTraffic: String { localized("gauge.ambient.cityTraffic") }
    static var gaugeAmbientLawnMower: String { localized("gauge.ambient.lawnMower") }
    static var gaugeAmbientJetTakeoff: String { localized("gauge.ambient.jetTakeoff") }
    static var spectrumLoading: String { localized("spectrum.loading") }
    static var spectrumIdle: String { localized("spectrum.idle") }

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
    static var micPermissionIntroTitle: String { localized("permission.microphone.intro.title") }
    static var micPermissionIntroBody: String { localized("permission.microphone.intro.body") }
    static var micPermissionIntroPointMeasure: String { localized("permission.microphone.intro.point.measure") }
    static var micPermissionIntroPointLocal: String { localized("permission.microphone.intro.point.local") }
    static var micPermissionIntroPointSleep: String { localized("permission.microphone.intro.point.sleep") }
    static var micPermissionIntroContinue: String { localized("permission.microphone.intro.continue") }

    // MARK: - App onboarding

    static var appOnboardingStepMeasureTitle: String { localized("onboarding.app.step.measure.title") }
    static var appOnboardingStepMeasureBody: String { localized("onboarding.app.step.measure.body") }
    static var appOnboardingStepSleepTitle: String { localized("onboarding.app.step.sleep.title") }
    static var appOnboardingStepSleepBody: String { localized("onboarding.app.step.sleep.body") }
    static var appOnboardingStepExportTitle: String { localized("onboarding.app.step.export.title") }
    static var appOnboardingStepExportBody: String { localized("onboarding.app.step.export.body") }
    static var appTaskOnboardingTitle: String { localized("onboarding.app.task.title") }
    static var appTaskOnboardingMeasureBody: String { localized("onboarding.app.task.measure.body") }
    static var appTaskOnboardingFilesBody: String { localized("onboarding.app.task.files.body") }
    static var monitorSessionSummaryPreviousMax: String { localized("monitor.sessionSummary.previousMax") }
    static var filesEmptyAudioMonitoringMessage: String { localized("files.empty.audio.monitoring.message") }
    static var filesEmptyVideoMonitoringMessage: String { localized("files.empty.video.monitoring.message") }

    // MARK: - Monitor session summary

    static var monitorSessionSummaryTitle: String { localized("monitor.sessionSummary.title") }
    static var monitorSessionSummaryDuration: String { localized("monitor.sessionSummary.duration") }
    static var monitorSessionSummaryMax: String { localized("monitor.sessionSummary.max") }
    static var monitorSessionSummaryAverage: String { localized("monitor.sessionSummary.average") }
    static var monitorSessionSummaryHint: String { localized("monitor.sessionSummary.hint") }
    static var monitorSessionSummarySleepCTA: String { localized("monitor.sessionSummary.sleepCTA") }
    static var monitorSessionSummaryHistoryCTA: String { localized("monitor.sessionSummary.historyCTA") }
    static var monitorSessionEndFileSize: String { localized("monitor.sessionEnd.fileSize") }

    static func monitorSessionEndAutoSavedClips(_ count: Int) -> String {
        String(format: localized("monitor.sessionEnd.autoSavedClips"), count)
    }

    static var monitorSessionEndSavedToFiles: String { localized("monitor.sessionEnd.savedToFiles") }
    static var permissionCameraDeniedTitle: String { localized("permission.camera.denied.title") }
    static var permissionCameraDeniedMessage: String { localized("permission.camera.denied.message") }
    static var permissionLocationDeniedTitle: String { localized("permission.location.denied.title") }
    static var permissionLocationDeniedMessage: String { localized("permission.location.denied.message") }
    static var permissionLocationWeatherDeniedTitle: String { localized("permission.location.weather.denied.title") }
    static var permissionLocationWeatherDeniedMessage: String { localized("permission.location.weather.denied.message") }
    static var permissionPhotosDeniedTitle: String { localized("permission.photos.denied.title") }
    static var permissionPhotosDeniedMessage: String { localized("permission.photos.denied.message") }
    static var playerSaveToPhotos: String { localized("player.saveToPhotos") }
    static var playerSavedVideoToPhotos: String { localized("player.savedToPhotos.video") }
    static var playerSavedPhotoToPhotos: String { localized("player.savedToPhotos.photo") }

    static func playerSavedItemsToPhotos(_ count: Int) -> String {
        String(format: localized("player.savedToPhotos.batch"), count)
    }
    static var recorderMonitoringRequiredTitle: String { localized("recorder.monitoringRequired.title") }
    static var recorderMonitoringRequiredMessage: String { localized("recorder.monitoringRequired.message") }
    static var recorderMonitoringRequiredStart: String { localized("recorder.monitoringRequired.start") }
    static var recorderThresholdInvalid: String { localized("recorder.threshold.invalid") }
    static var recorderAiFilterEmpty: String { localized("recorder.aiFilter.empty") }
    static var dashboardExportCSVFailed: String { localized("dashboard.exportCSV.failed") }
    static var filesRenameFailed: String { localized("files.rename.failed") }
    static var filesBatchShare: String { localized("files.batchShare") }
    static var filesBatchSaveToPhotos: String { localized("files.batchSaveToPhotos") }
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
    static var settingsPrivacyChoices: String { localized("settings.privacyChoices") }
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
    static var settingsAccentColor: String { localized("settings.accentColor") }
    static var settingsAccentColorFooter: String { localized("settings.accentColor.footer") }
    static var settingsAccentColorSource: String { localized("settings.accentColor.source") }
    static var settingsAccentColorAutomatic: String { localized("settings.accentColor.automatic") }
    static var settingsAccentColorPreset: String { localized("settings.accentColor.preset") }
    static var settingsAccentCustom: String { localized("settings.accentColor.custom") }
    static var settingsAccentPreview: String { localized("settings.accentColor.preview") }
    static var settingsTemperatureUnit: String { localized("settings.temperature.unit") }
    static var settingsTemperatureCelsius: String { localized("settings.temperature.celsius") }
    static var settingsTemperatureFahrenheit: String { localized("settings.temperature.fahrenheit") }
    static var settingsTemperatureFooter: String { localized("settings.temperature.footer") }
    static var settingsRemoveAdsHeader: String { localized("settings.removeAds.header") }
    static var settingsRemoveAdsFooter: String { localized("settings.removeAds.footer") }
    static var settingsRemoveAdsBannerTitle: String { localized("settings.removeAds.banner.title") }
    static var settingsRemoveAdsBannerSubtitle: String { localized("settings.removeAds.banner.subtitle") }
    static var settingsRemoveAdsSheetTitle: String { localized("settings.removeAds.sheet.title") }
    static var settingsRemoveAdsSheetHeadline: String { localized("settings.removeAds.sheet.headline") }
    static var settingsRemoveAdsSheetSubheadline: String { localized("settings.removeAds.sheet.subheadline") }
    static var settingsRemoveAdsBenefitNoAppOpen: String { localized("settings.removeAds.benefit.noAppOpen") }
    static var settingsRemoveAdsBenefitNoInterstitial: String { localized("settings.removeAds.benefit.noInterstitial") }
    static var settingsRemoveAdsBenefitLifetime: String { localized("settings.removeAds.benefit.lifetime") }
    static var settingsRemoveAdsPriceOriginal: String { localized("settings.removeAds.price.original") }
    static var settingsRemoveAdsPriceSale: String { localized("settings.removeAds.price.sale") }
    static var settingsRemoveAdsPriceNote: String { localized("settings.removeAds.price.note") }
    static var settingsRemoveAdsProductLoaded: String { localized("settings.removeAds.product.loaded") }
    static var settingsRemoveAdsProductFallback: String { localized("settings.removeAds.product.fallback") }
    static var settingsRemoveAdsCancelledTitle: String { localized("settings.removeAds.alert.cancelled.title") }
    static var settingsRemoveAdsCancelledMessage: String { localized("settings.removeAds.alert.cancelled.message") }
    static var settingsRemoveAdsPurchaseFallback: String { localized("settings.removeAds.purchaseFallback") }
    static var settingsRemoveAdsRestore: String { localized("settings.removeAds.restore") }
    static var settingsRemoveAdsActive: String { localized("settings.removeAds.active") }
    static var settingsRemoveAdsPurchasedTitle: String { localized("settings.removeAds.alert.purchased.title") }
    static var settingsRemoveAdsPurchasedMessage: String { localized("settings.removeAds.alert.purchased.message") }
    static var settingsRemoveAdsPendingTitle: String { localized("settings.removeAds.alert.pending.title") }
    static var settingsRemoveAdsPendingMessage: String { localized("settings.removeAds.alert.pending.message") }
    static var settingsRemoveAdsRestoredTitle: String { localized("settings.removeAds.alert.restored.title") }
    static var settingsRemoveAdsRestoredMessage: String { localized("settings.removeAds.alert.restored.message") }
    static var settingsRemoveAdsErrorTitle: String { localized("settings.removeAds.alert.error.title") }

    static func settingsRemoveAdsPurchase(price: String) -> String {
        String(format: localized("settings.removeAds.purchase"), price)
    }

    static var iapErrorProductNotFound: String { localized("iap.error.productNotFound") }
    static var iapErrorVerificationFailed: String { localized("iap.error.verificationFailed") }
    static var iapErrorNothingToRestore: String { localized("iap.error.nothingToRestore") }
    static var iapErrorEntitlementNotGranted: String { localized("iap.error.entitlementNotGranted") }
    static var iapErrorUnknown: String { localized("iap.error.unknown") }

    // MARK: - Paywall

    static var paywallTitle: String { localized("paywall.title") }
    static var paywallHeadline: String { localized("paywall.headline") }
    static var paywallEarlySupporterMessage: String { localized("paywall.earlySupporter") }
    static var paywallBestValue: String { localized("paywall.bestValue") }
    static var paywallTierWeekly: String { localized("paywall.tier.weekly") }
    static var paywallTierMonthly: String { localized("paywall.tier.monthly") }
    static var paywallTierYearly: String { localized("paywall.tier.yearly") }
    static var paywallContinue: String { localized("paywall.continue") }
    static var paywallLegalFooter: String { localized("paywall.legalFooter") }
    static var paywallPurchasedTitle: String { localized("paywall.alert.purchased.title") }
    static var paywallPurchasedMessage: String { localized("paywall.alert.purchased.message") }
    static var paywallBenefitVideo: String { localized("paywall.benefit.video") }
    static var paywallBenefitAI: String { localized("paywall.benefit.ai") }
    static var paywallBenefitSleepReport: String { localized("paywall.benefit.sleepReport") }
    static var paywallBenefitVoiceUnlimited: String { localized("paywall.benefit.voiceUnlimited") }
    static var paywallBenefitNoAds: String { localized("paywall.benefit.noAds") }
    static var paywallContextVideo: String { localized("paywall.context.video") }
    static var paywallContextAI: String { localized("paywall.context.ai") }
    static var paywallContextSpectrum: String { localized("paywall.context.spectrum") }
    static var paywallContextVoiceDuration: String { localized("paywall.context.voiceDuration") }
    static var paywallContextVideoDaily: String { localized("paywall.context.videoDaily") }
    static var paywallContextVideoDuration: String { localized("paywall.context.videoDuration") }
    static var paywallUpgradeBannerTitle: String { localized("paywall.banner.title") }
    static var paywallUpgradeBannerSubtitle: String { localized("paywall.banner.subtitle") }
    static var paywallVIPBannerTitle: String { localized("paywall.banner.vip.title") }
    static var paywallVIPBannerSubtitle: String { localized("paywall.banner.vip.subtitle") }
    static var paywallPriceWeeklyFallback: String { localized("paywall.price.weekly.fallback") }
    static var paywallPriceMonthlyFallback: String { localized("paywall.price.monthly.fallback") }
    static var paywallPriceYearlyMonthlyFallback: String { localized("paywall.price.yearly.monthly.fallback") }
    static var paywallPriceMonthlyDailyFallback: String { localized("paywall.price.monthly.daily.fallback") }
    static var paywallPriceYearlyFallback: String { localized("paywall.price.yearly.fallback") }

    static func paywallWeeklyPrice(_ price: String) -> String {
        String(format: localized("paywall.price.weekly"), price)
    }

    static func paywallMonthlyPrice(_ price: String) -> String {
        String(format: localized("paywall.price.monthly"), price)
    }

    static func paywallYearlyPrice(_ price: String) -> String {
        String(format: localized("paywall.price.yearly"), price)
    }

    static func paywallYearlyMonthlyEquivalent(_ price: String) -> String {
        String(format: localized("paywall.price.yearly.monthly"), price)
    }

    static func paywallMonthlyDailyEquivalent(_ price: String) -> String {
        String(format: localized("paywall.price.monthly.daily"), price)
    }

    static func paywallCTAStartFreeTrial(days: Int) -> String {
        String(format: localized("paywall.cta.startFreeTrial"), days)
    }

    static var paywallCTASubscribeNow: String { localized("paywall.cta.subscribeNow") }

    static func paywallCTASubtitleTrialYearly(monthlyPrice: String, trialDays: Int) -> String {
        String(format: localized("paywall.cta.subtitle.trialYearly"), monthlyPrice, trialDays)
    }

    static func paywallCTASubtitleTrialMonthly(monthlyPrice: String, trialDays: Int) -> String {
        String(format: localized("paywall.cta.subtitle.trialMonthly"), monthlyPrice, trialDays)
    }

    static func paywallCTASubtitleStandardYearly(annualPrice: String, monthlyPrice: String) -> String {
        String(format: localized("paywall.cta.subtitle.standardYearly"), annualPrice, monthlyPrice)
    }

    static func paywallCTASubtitleStandardWeekly(_ price: String) -> String {
        String(format: localized("paywall.cta.subtitle.standardWeekly"), price)
    }

    static func paywallCTASubtitleStandardMonthly(_ price: String) -> String {
        String(format: localized("paywall.cta.subtitle.standardMonthly"), price)
    }

    static func paywallTrialDisclaimer(days: Int) -> String {
        String(format: localized("paywall.trialDisclaimer"), days)
    }

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

    // MARK: - Media detail

    static var mediaDetailTabPicker: String { localized("mediaDetail.tabPicker") }
    static var mediaDetailTabWaveform: String { localized("mediaDetail.tab.waveform") }
    static var mediaDetailTabLevels: String { localized("mediaDetail.tab.levels") }
    static var mediaDetailTabExposure: String { localized("mediaDetail.tab.exposure") }
    static var mediaDetailAnalyzingWaveform: String { localized("mediaDetail.analyzingWaveform") }
    static var mediaDetailNoWaveformTitle: String { localized("mediaDetail.noWaveform.title") }
    static var mediaDetailNoWaveformMessage: String { localized("mediaDetail.noWaveform.message") }
    static var mediaDetailPlay: String { localized("mediaDetail.play") }
    static var mediaDetailPause: String { localized("mediaDetail.pause") }
    static var mediaDetailLocationTitle: String { localized("mediaDetail.locationTitle") }
    static var mediaDetailLocationUnknown: String { localized("mediaDetail.locationUnknown") }
    static var mediaDetailNotesTitle: String { localized("mediaDetail.notesTitle") }
    static var mediaDetailNotesPlaceholder: String { localized("mediaDetail.notesPlaceholder") }
    static var mediaDetailExposureSection: String { localized("mediaDetail.exposureSection") }
    static var mediaDetailSoundLevelsSection: String { localized("mediaDetail.soundLevelsSection") }
    static var mediaDetailDuration: String { localized("mediaDetail.duration") }
    static var mediaDetailDose: String { localized("mediaDetail.dose") }
    static var mediaDetailProjectedDose: String { localized("mediaDetail.projectedDose") }
    static var mediaDetailTimeAveragedExposure: String { localized("mediaDetail.timeAveragedExposure") }
    static var mediaDetailPeak: String { localized("mediaDetail.peak") }
    static var mediaDetailMaximum: String { localized("mediaDetail.maximum") }
    static var mediaDetailTimeAveraged: String { localized("mediaDetail.timeAveraged") }
    static var mediaDetailLAeq: String { localized("mediaDetail.laeq") }
    static var mediaDetailNotAvailable: String { localized("mediaDetail.notAvailable") }
    static var mediaDetailMeterConfiguration: String { localized("mediaDetail.meterConfiguration") }
    static var mediaDetailExposureConfiguration: String { localized("mediaDetail.exposureConfiguration") }
    static var mediaDetailTimeWeighting: String { localized("mediaDetail.timeWeighting") }
    static var mediaDetailTimeWeightingSlow: String { localized("mediaDetail.timeWeightingSlow") }
    static var mediaDetailFrequencyWeighting: String { localized("mediaDetail.frequencyWeighting") }
    static var mediaDetailPeakFrequencyWeighting: String { localized("mediaDetail.peakFrequencyWeighting") }
    static var mediaDetailCriterionDuration: String { localized("mediaDetail.criterionDuration") }
    static var mediaDetailCriterionDurationValue: String { localized("mediaDetail.criterionDurationValue") }
    static var mediaDetailCriterionLevel: String { localized("mediaDetail.criterionLevel") }
    static var mediaDetailCriterionLevelValue: String { localized("mediaDetail.criterionLevelValue") }
    static var mediaDetailThresholdLevel: String { localized("mediaDetail.thresholdLevel") }
    static var mediaDetailThresholdLevelValue: String { localized("mediaDetail.thresholdLevelValue") }
    static var mediaDetailExchangeRate: String { localized("mediaDetail.exchangeRate") }
    static var mediaDetailExchangeRateValue: String { localized("mediaDetail.exchangeRateValue") }
    static var mediaDetailMetricInfoAccessibility: String { localized("mediaDetail.metricInfoAccessibility") }
    static var mediaDetailInfoDuration: String { localized("mediaDetail.info.duration") }
    static var mediaDetailInfoDose: String { localized("mediaDetail.info.dose") }
    static var mediaDetailInfoProjectedDose: String { localized("mediaDetail.info.projectedDose") }
    static var mediaDetailInfoTimeAveraged: String { localized("mediaDetail.info.timeAveraged") }
    static var mediaDetailInfoPeak: String { localized("mediaDetail.info.peak") }
    static var mediaDetailInfoMaximum: String { localized("mediaDetail.info.maximum") }
    static var mediaDetailInfoLAeq: String { localized("mediaDetail.info.laeq") }
    static var mediaDetailInfoTimeWeighting: String { localized("mediaDetail.info.timeWeighting") }
    static var mediaDetailInfoFrequencyWeighting: String { localized("mediaDetail.info.frequencyWeighting") }
    static var mediaDetailInfoPeakWeighting: String { localized("mediaDetail.info.peakWeighting") }
    static var mediaDetailInfoCriterionDuration: String { localized("mediaDetail.info.criterionDuration") }
    static var mediaDetailInfoCriterionLevel: String { localized("mediaDetail.info.criterionLevel") }
    static var mediaDetailInfoThresholdLevel: String { localized("mediaDetail.info.thresholdLevel") }
    static var mediaDetailInfoExchangeRate: String { localized("mediaDetail.info.exchangeRate") }

    // MARK: - Sleep monitor

    static var sleepMonitorTitle: String { localized("sleep.monitor.title") }
    static var sleepMonitorSubtitle: String { localized("sleep.monitor.subtitle") }
    static var sleepMonitorPowerHint: String { localized("sleep.monitor.powerHint") }
    static var sleepMonitorModeHint: String { localized("sleep.monitor.modeHint") }
    static var sleepMonitorStart: String { localized("sleep.monitor.start") }
    static var sleepMonitorHeaderButton: String { localized("sleep.monitor.headerButton") }
    static var sleepMenuStart: String { localized("sleep.menu.start") }
    static var sleepMenuLatestReport: String { localized("sleep.menu.latestReport") }
    static var sleepMenuHistory: String { localized("sleep.menu.history") }
    static var sleepMenuNoReport: String { localized("sleep.menu.noReport") }
    static var sleepMenuMonitoringBlocked: String { localized("sleep.menu.monitoringBlocked") }
    static var sleepActiveTitle: String { localized("sleep.active.title") }
    static var sleepActiveCurrent: String { localized("sleep.active.current") }
    static var sleepActiveNoiseFloor: String { localized("sleep.active.noiseFloor") }
    static var sleepActiveAnomalies: String { localized("sleep.active.anomalies") }
    static var sleepEndSession: String { localized("sleep.endSession") }
    static var sleepReportTitle: String { localized("sleep.report.title") }
    static var sleepReportDisclaimer: String { localized("sleep.report.disclaimer") }
    static var sleepReportAnomaliesTitle: String { localized("sleep.report.anomaliesTitle") }
    static var sleepReportViewHistory: String { localized("sleep.report.viewHistory") }
    static var sleepReportExport: String { localized("sleep.report.export") }
    static var sleepReportExportPDF: String { localized("sleep.report.exportPDF") }
    static var sleepReportPDFUnlockTitle: String { localized("sleep.report.pdfUnlockTitle") }
    static var sleepReportImpactDeepSleep: String { localized("sleep.report.impactDeepSleep") }
    static var sleepReportImpactLightSleep: String { localized("sleep.report.impactLightSleep") }
    static var sleepHistoryTitle: String { localized("sleep.history.title") }
    static var sleepHistorySubtitle: String { localized("sleep.history.subtitle") }
    static var sleepHistoryEmpty: String { localized("sleep.history.empty") }
    static var sleepHistoryTrendTitle: String { localized("sleep.history.trendTitle") }
    static var sleepHistoryQuietNight: String { localized("sleep.history.quietNight") }
    static var sleepHistoryChartFloorLegend: String { localized("sleep.history.chart.floorLegend") }
    static var sleepSettingsHeader: String { localized("sleep.settings.header") }
    static var sleepSettingsWakeTime: String { localized("sleep.settings.wakeTime") }
    static var sleepSettingsNotifications: String { localized("sleep.settings.notifications") }
    static var sleepNotificationWakeTitle: String { localized("sleep.notification.wakeTitle") }
    static var sleepNotificationWakeBody: String { localized("sleep.notification.wakeBody") }
    static var sleepNotificationBedtimeTitle: String { localized("sleep.notification.bedtimeTitle") }
    static var sleepNotificationBedtimeBody: String { localized("sleep.notification.bedtimeBody") }
    static var sleepNotificationOvernightActivationTitle: String { localized("sleep.notification.overnightActivationTitle") }
    static var sleepNotificationOvernightActivationBody: String { localized("sleep.notification.overnightActivationBody") }
    static var sleepNotificationReportTitle: String { localized("sleep.notification.reportTitle") }
    static var paywallContextSleepHistory: String { localized("paywall.context.sleepHistory") }
    static var paywallContextSleepExport: String { localized("paywall.context.sleepExport") }

    static func sleepReportOverallLevel(_ level: String) -> String {
        String(format: localized("sleep.report.overallLevel"), level)
    }

    static func sleepReportFloorLevel(_ level: String) -> String {
        String(format: localized("sleep.report.floorLevel"), level)
    }

    static func sleepReportSummaryQuiet(_ overall: String) -> String {
        String(format: localized("sleep.report.summaryQuiet"), overall)
    }

    static func sleepReportSummaryWithAnomaly(
        _ overall: String,
        _ time: String,
        _ peak: String,
        _ impact: String
    ) -> String {
        String(format: localized("sleep.report.summaryWithAnomaly"), overall, time, peak, impact)
    }

    static func sleepHistoryRowSummary(leq: String, floor: String, anomalies: Int) -> String {
        String(format: localized("sleep.history.rowSummary"), leq, floor, anomalies)
    }

    static func sleepHistoryRowMetrics(overall: String, floor: String) -> String {
        String(format: localized("sleep.history.rowMetrics"), overall, floor)
    }

    static func sleepHistoryMonitoringDuration(_ duration: String) -> String {
        String(format: localized("sleep.history.monitoringDuration"), duration)
    }

    static func sleepHistoryAnomaliesCount(_ count: Int) -> String {
        String(format: localized("sleep.history.anomaliesCount"), count)
    }

    static func sleepHistorySummaryAvgLeq(_ level: String) -> String {
        String(format: localized("sleep.history.summary.avgLeq"), level)
    }

    static func sleepHistorySummaryBestNight(_ date: String, _ grade: String) -> String {
        String(format: localized("sleep.history.summary.bestNight"), date, grade)
    }

    static func sleepHistorySummaryWorstNight(_ date: String, _ grade: String) -> String {
        String(format: localized("sleep.history.summary.worstNight"), date, grade)
    }

    static func sleepHistorySummaryTotalAnomalies(_ count: Int) -> String {
        String(format: localized("sleep.history.summary.totalAnomalies"), count)
    }

    // MARK: - AI labels

    static func aiLabel(_ key: String) -> String {
        AppLocalization.string(String.LocalizationValue("aiLabel.\(key)"))
    }
}
