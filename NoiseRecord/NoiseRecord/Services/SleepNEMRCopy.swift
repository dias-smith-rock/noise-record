import Foundation

/// Bilingual NEMR copy: selected language is primary; English is secondary.
/// When primary is English, output is English-only.
struct SleepNEMRCopy: Sendable {
    let primaryLanguage: AppLanguage

    var includesEnglishSecondary: Bool {
        primaryLanguage != .en
    }

    init(primaryLanguage: AppLanguage) {
        self.primaryLanguage = AppLocalization.resolvedAppLanguage(for: primaryLanguage)
    }

    // MARK: - Composition

    func phrase(_ key: String.LocalizationValue) -> String {
        let primary = string(key)
        guard includesEnglishSecondary else { return primary }
        let english = string(key, language: .en)
        if primary == english { return primary }
        return "\(primary) (\(english))"
    }

    func phrase(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let primary = formatted(key, language: primaryLanguage, arguments)
        guard includesEnglishSecondary else { return primary }
        let english = formatted(key, language: .en, arguments)
        if primary == english { return primary }
        return "\(primary) (\(english))"
    }

    func stacked(_ key: String.LocalizationValue) -> String {
        let primary = string(key)
        guard includesEnglishSecondary else { return primary }
        let english = string(key, language: .en)
        if primary == english { return primary }
        return "\(primary)\n\n\(english)"
    }

    func stacked(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let primary = formatted(key, language: primaryLanguage, arguments)
        guard includesEnglishSecondary else { return primary }
        let english = formatted(key, language: .en, arguments)
        if primary == english { return primary }
        return "\(primary)\n\n\(english)"
    }

    func pair(primaryKey: String.LocalizationValue, secondaryPlain english: String) -> String {
        let primary = string(primaryKey)
        guard includesEnglishSecondary else { return primary }
        if primary == english { return primary }
        return "\(primary) (\(english))"
    }

    // MARK: - Cover & sections

    var coverTitlePrimary: String { string("sleep.nemr.cover.title") }
    var coverTitleSecondary: String? {
        includesEnglishSecondary ? string("sleep.nemr.cover.title", language: .en) : nil
    }

    var fieldReportNo: String { phrase("sleep.nemr.field.reportNo") }
    var fieldMonitoringDate: String { phrase("sleep.nemr.field.monitoringDate") }
    var fieldReportDate: String { phrase("sleep.nemr.field.reportDate") }
    var fieldClient: String { phrase("sleep.nemr.field.client") }
    var fieldSiteAddress: String { phrase("sleep.nemr.field.siteAddress") }
    var fieldPurpose: String { phrase("sleep.nemr.field.purpose") }
    var fieldFirm: String { phrase("sleep.nemr.field.firm") }

    var sectionIntroduction: String { "1. \(phrase("sleep.nemr.section.introduction"))" }
    var sectionStandards: String { "2. \(phrase("sleep.nemr.section.standards"))" }
    var sectionInstrumentation: String { "3. \(phrase("sleep.nemr.section.instrumentation"))" }
    var sectionLocations: String { "4. \(phrase("sleep.nemr.section.locations"))" }
    var sectionResults: String { "5. \(phrase("sleep.nemr.section.results"))" }
    var sectionConclusion: String { "6. \(phrase("sleep.nemr.section.conclusion"))" }
    var sectionAppendices: String { "7. \(phrase("sleep.nemr.section.appendices"))" }
    var sectionDisclaimer: String { "8. \(phrase("sleep.nemr.section.disclaimer"))" }

    var subsectionPlacement: String { "4.1 \(phrase("sleep.nemr.sub.placement"))" }
    var subsectionPointDescription: String { "4.2 \(phrase("sleep.nemr.sub.pointDescription"))" }
    var subsectionPeriodMethod: String { "4.3 \(phrase("sleep.nemr.sub.periodMethod"))" }

    var table1Title: String { phrase("sleep.nemr.table1.title") }
    var table2Title: String { phrase("sleep.nemr.table2.title") }
    var trendTitle: String { phrase("sleep.nemr.trend.title") }
    var anomalyLogTitle: String { phrase("sleep.nemr.anomalyLog.title") }

    var placementParagraph: String { stacked("sleep.nemr.placement.body") }

    var purposeValue: String { stacked("sleep.nemr.purpose.value") }

    var clientPlaceholder: String { phrase("sleep.nemr.placeholder.client") }
    var sitePlaceholder: String { phrase("sleep.nemr.placeholder.site") }
    var firmPlaceholder: String { phrase("sleep.nemr.placeholder.firm") }
    var siteMapPlaceholder: String { phrase("sleep.nemr.placeholder.siteMap") }
    var notRecorded: String { phrase("sleep.nemr.value.notRecorded") }

    func introduction(client: String, firm: String, monitoringDate: String, siteAddress: String) -> String {
        stacked(
            "sleep.nemr.introduction.body",
            client, firm, monitoringDate, siteAddress
        )
    }

    // MARK: - Instrumentation / methodology labels

    var labelSoundLevelMeter: String { phrase("sleep.nemr.label.soundLevelMeter") }
    var labelWeighting: String { phrase("sleep.nemr.label.weighting") }
    var labelTimeResponse: String { phrase("sleep.nemr.label.timeResponse") }
    var labelCalibrator: String { phrase("sleep.nemr.label.calibrator") }
    var labelCalibrationRecord: String { phrase("sleep.nemr.label.calibrationRecord") }
    var labelTemperatureHumidity: String { phrase("sleep.nemr.label.temperatureHumidity") }
    var labelGPS: String { phrase("sleep.nemr.label.gps") }
    var labelMonitoringWindow: String { phrase("sleep.nemr.label.monitoringWindow") }
    var labelMeasurementDuration: String { phrase("sleep.nemr.label.measurementDuration") }
    var labelSamplingInterval: String { phrase("sleep.nemr.label.samplingInterval") }
    var labelSiteMap: String { phrase("sleep.nemr.label.siteMap") }

    var weightingA: String { phrase("sleep.nemr.weighting.a") }
    var weightingC: String { phrase("sleep.nemr.weighting.c") }
    var weightingZ: String { phrase("sleep.nemr.weighting.z") }
    var timeResponseValue: String { phrase("sleep.nemr.timeResponse.value") }
    var calibratorValue: String { phrase("sleep.nemr.calibrator.value") }

    func calibrationUserOffset(offset: Float, referenceSPL: Float) -> String {
        stacked(
            "sleep.nemr.calibration.userOffset",
            String(format: "%+.1f", offset),
            String(format: "%.0f", referenceSPL)
        )
    }

    var calibrationFactory: String { stacked("sleep.nemr.calibration.factory") }

    func measurementDurationValue(_ duration: String) -> String {
        phrase("sleep.nemr.measurementDuration.value", duration)
    }

    func samplingIntervalValue(seconds: Int, sampleCount: Int) -> String {
        phrase(
            "sleep.nemr.samplingInterval.value",
            seconds,
            sampleCount
        )
    }

    func locationDescription(siteAddress: String) -> String {
        phrase("sleep.nemr.location.description", siteAddress)
    }

    var locationSource: String { phrase("sleep.nemr.location.source") }

    var colPoint: String { phrase("sleep.nemr.col.point") }
    var colDescription: String { phrase("sleep.nemr.col.description") }
    var colSource: String { phrase("sleep.nemr.col.source") }
    var colStandard: String { phrase("sleep.nemr.col.standard") }
    var colTitleApplication: String { phrase("sleep.nemr.col.titleApplication") }

    func localOrdinanceRow(limit: Float) -> String {
        phrase("sleep.nemr.standard.localOrdinance", String(format: "%.0f", limit))
    }

    var standardANSI: String { phrase("sleep.nemr.standard.ansi") }
    var standardEPA: String { phrase("sleep.nemr.standard.epa") }
    var standardHUD: String { phrase("sleep.nemr.standard.hud") }
    var standardLocalName: String { phrase("sleep.nemr.standard.localName") }

    var compliancePass: String { phrase("sleep.nemr.compliance.pass") }
    var complianceExceed: String { phrase("sleep.nemr.compliance.exceed") }
    var complianceNonCompliant: String { phrase("sleep.nemr.compliance.nonCompliant") }

    func compliance(_ status: SleepNEMRStatistics.ComplianceStatus) -> String {
        switch status {
        case .pass: compliancePass
        case .exceed: complianceExceed
        case .nonCompliant: complianceNonCompliant
        }
    }

    // MARK: - Conclusion / disclaimer / signatures

    func conclusionExceed(point: String, leq: Float, limit: Float) -> String {
        stacked(
            "sleep.nemr.conclusion.exceed",
            point,
            String(format: "%.1f", leq),
            String(format: "%.0f", limit)
        )
    }

    func conclusionWithin(point: String, leq: Float, limit: Float) -> String {
        stacked(
            "sleep.nemr.conclusion.within",
            point,
            String(format: "%.1f", leq),
            String(format: "%.0f", limit)
        )
    }

    func conclusionPeaksSignificant(point: String, count: Int, threshold: Float, max: Float) -> String {
        stacked(
            "sleep.nemr.conclusion.peaksSignificant",
            point,
            count,
            String(format: "%.0f", threshold),
            String(format: "%.1f", max)
        )
    }

    func conclusionPeaksNone(threshold: Float) -> String {
        stacked("sleep.nemr.conclusion.peaksNone", String(format: "%.0f", threshold))
    }

    func backgroundNoCorrection(l90: Float, leq: Float) -> String {
        stacked(
            "sleep.nemr.background.noCorrection",
            String(format: "%.1f", l90),
            String(format: "%.1f", leq)
        )
    }

    func backgroundNeedsCorrection(l90: Float, leq: Float) -> String {
        stacked(
            "sleep.nemr.background.needsCorrection",
            String(format: "%.1f", l90),
            String(format: "%.1f", leq)
        )
    }

    var recommendationConstruction: String { stacked("sleep.nemr.recommendation.construction") }
    var recommendationEngineering: String { stacked("sleep.nemr.recommendation.engineering") }
    var recommendationFollowUp: String { stacked("sleep.nemr.recommendation.followUp") }

    var appendixPhoto1: String { phrase("sleep.nemr.appendix.photo1") }
    var appendixPhoto2: String { phrase("sleep.nemr.appendix.photo2") }
    var appendixPhoto3: String { phrase("sleep.nemr.appendix.photo3") }
    var appendixA: String { phrase("sleep.nemr.appendix.a") }
    var appendixB: String { phrase("sleep.nemr.appendix.b") }

    var disclaimerPeriod: String { stacked("sleep.nemr.disclaimer.period") }
    var disclaimerDevice: String { stacked("sleep.nemr.disclaimer.device") }

    func disclaimerReproduction(firm: String) -> String {
        stacked("sleep.nemr.disclaimer.reproduction", firm)
    }

    var preparedBy: String { phrase("sleep.nemr.sign.preparedBy") }
    var titleSignatory: String { phrase("sleep.nemr.sign.title") }
    var reviewedBy: String { phrase("sleep.nemr.sign.reviewedBy") }
    var issuingAuthority: String { phrase("sleep.nemr.sign.issuingAuthority") }

    var peakTableHeaders: [String] {
        [
            phrase("sleep.nemr.peak.col.point"),
            phrase("sleep.nemr.peak.col.count"),
            phrase("sleep.nemr.peak.col.times"),
            phrase("sleep.nemr.peak.col.max"),
            phrase("sleep.nemr.peak.col.compliance"),
        ]
    }

    // MARK: - Private

    private func string(_ key: String.LocalizationValue, language: AppLanguage? = nil) -> String {
        AppLocalization.string(key, language: language ?? primaryLanguage)
    }

    private func formatted(
        _ key: String.LocalizationValue,
        language: AppLanguage,
        _ arguments: [CVarArg]
    ) -> String {
        let template = AppLocalization.string(key, language: language)
        return String(
            format: template,
            locale: AppLocalization.resolvedLocale(for: language),
            arguments: arguments
        )
    }
}

extension AppLanguage {
    /// NEMR PDF primary-language choices (English is always secondary, or sole language is not offered).
    static var nemrReportChoices: [AppLanguage] {
        [.es, .pt, .ar, .fr, .zhHant]
    }
}
