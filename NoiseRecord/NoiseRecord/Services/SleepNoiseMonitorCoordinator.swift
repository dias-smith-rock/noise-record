import Foundation
import SwiftData

@Observable
@MainActor
final class SleepNoiseMonitorCoordinator {
    private(set) var activeSession: SleepNoiseSession?
    private(set) var latestReportSessionID: UUID?
    private(set) var showReportSheet = false
    private(set) var liveAnomalyCount = 0
    private(set) var liveNoiseFloor: Float?
    private(set) var liveCurrentDB: Float = 0
    private(set) var isHighSensitivitySession = false

    private weak var engine: NoiseMonitorEngine?
    private var modelContext: ModelContext?
    private var savedHighSensitivity = false
    private var savedVoiceActivated = false
    private var savedBackgroundMonitoring = false
    private var inMemorySamples: [(timestamp: Date, leq: Float, peak: Float)] = []
    private var lastSleepSessionIDForRecording: UUID?
    private var recentLevelSamples: [Float] = []
    private var recentPeakSamples: [Float] = []
    private var intervalPeakDB: Float = 0
    private var liveAnomalyEvents: [SleepAnomalyCandidate] = []
    private var lastRecentSampleTime = Date.distantPast
    private var lastVADThresholdUpdate = Date.distantPast
    private static let recentSampleInterval: TimeInterval = 1
    private static let recentSampleCapacity = 300
    private static let liveMetricsWarmup: TimeInterval = 5
    private static let vadThresholdRefreshInterval: TimeInterval = 5

    func configure(engine: NoiseMonitorEngine, modelContext: ModelContext) {
        self.engine = engine
        self.modelContext = modelContext
        engine.onSleepSampleDue = { [weak self] in
            self?.handleSleepSampleDue()
        }
        engine.onSleepAnomalyClipFinished = { [weak self] event in
            self?.handleAnomalyClipFinished(event)
        }
        engine.onSleepMetricsRefresh = { [weak self] currentDB, minDB, leq in
            self?.refreshLiveMetrics(currentDB: currentDB, minDB: minDB, leq: leq)
        }
        restorePendingReportIfNeeded()
    }

    var isSleepMonitoring: Bool {
        activeSession?.sessionStatus == .active
    }

    func startSession(isHighSensitivity: Bool) async -> Bool {
        guard let engine, let modelContext else { return false }
        guard activeSession == nil else { return false }

        if !engine.permissionGranted {
            await engine.requestPermissionAndStart()
            guard engine.permissionGranted else { return false }
        }

        _ = await SleepNotificationScheduler.requestAuthorizationIfNeeded()
        await SleepNotificationScheduler.scheduleDailyWakeReminder()

        savedHighSensitivity = engine.isHighSensitivityMode
        savedVoiceActivated = engine.voiceActivatedEnabled
        savedBackgroundMonitoring = engine.backgroundMonitoringEnabled

        engine.isHighSensitivityMode = isHighSensitivity
        isHighSensitivitySession = isHighSensitivity

        let session = SleepNoiseSession()
        session.weightingMode = isHighSensitivity ? "highSensitivity" : "standard"
        modelContext.insert(session)
        try? modelContext.save()

        activeSession = session
        lastSleepSessionIDForRecording = session.id
        inMemorySamples = []
        liveAnomalyCount = 0
        liveNoiseFloor = nil
        liveCurrentDB = 0
        recentLevelSamples = []
        recentPeakSamples = []
        intervalPeakDB = 0
        liveAnomalyEvents = []
        lastRecentSampleTime = Date.distantPast
        lastVADThresholdUpdate = Date.distantPast

        engine.backgroundMonitoringEnabled = true
        engine.configureSleepMode(
            active: true,
            sleepSessionID: session.id
        )

        if !engine.isMonitoring {
            engine.startMonitoring()
        }

        applySleepVADThresholdsIfNeeded(for: session, engine: engine, force: true)

        return engine.isMonitoring
    }

    func endSession() async {
        guard let engine, let modelContext, let session = activeSession else { return }

        let finalSnapshot = finalEngineSnapshot(from: engine)
        if finalSnapshot.leq > 0 {
            SleepMeasurementPersistence.persistSample(
                engine: engine,
                sleepSessionID: session.id,
                in: modelContext
            )
        }

        let persistedSamples = SleepMeasurementPersistence.samples(for: session.id, in: modelContext)
            .map { sample in
                (
                    timestamp: sample.timestamp,
                    leq: sample.leq > 0 ? sample.leq : sample.dbCurrent,
                    peak: sample.dbMax > 0 ? sample.dbMax : sample.dbCurrent
                )
            }
        let samples = SleepNoiseAnalyzer.mergeReportSamples(
            persisted: persistedSamples,
            inMemory: inMemorySamples,
            recentLevels: recentLevelSamples,
            recentInterval: Self.recentSampleInterval,
            finalSnapshot: finalSnapshot
        )

        engine.configureSleepMode(active: false, sleepSessionID: nil)
        if engine.isMonitoring {
            engine.stopMonitoring(presentSessionSavePrompt: false)
        }

        restoreEnginePreferences(on: engine)

        let referenceDB = NoiseReferenceLimits.residentialNightDB
        let result = SleepNoiseAnalyzer.finalize(
            samples: samples,
            referenceDB: referenceDB,
            isHighSensitivity: session.isHighSensitivitySession
        )

        session.endedAt = Date()
        session.sessionStatus = .completed
        session.noiseFloorDB = result.noiseFloor
        session.overallLeq = result.overallLeq
        session.peakDB = result.peakDB
        session.anomalyCount = result.anomalies.count
        session.grade = SilenceGrade.from(leq: result.overallLeq).rawValue

        session.anomalies = result.anomalies.map { candidate in
            let hint = SleepNoiseAnalyzer.sleepImpactHint(for: candidate.timestamp)
            return SleepAnomalyEvent(
                timestamp: candidate.timestamp,
                peakDB: candidate.peakDB,
                durationSeconds: candidate.durationSeconds,
                sleepImpactHint: hint
            )
        }

        let summary = SleepReportBuilder.buildSummary(
            overallLeq: result.overallLeq,
            noiseFloor: result.noiseFloor,
            anomalies: result.anomalies
        )
        session.reportSummary = summary
        session.isReportRead = false

        AppReviewStore.noteCoreFeatureUsed(.sleepReport)

        linkRecordingsToAnomalies(session: session)

        try? modelContext.save()

        SleepMonitorSettingsStore.pendingReportSessionID = session.id
        latestReportSessionID = session.id
        showReportSheet = true
        activeSession = nil
        isHighSensitivitySession = false
        lastSleepSessionIDForRecording = session.id
        inMemorySamples = []
        recentLevelSamples = []
        recentPeakSamples = []
        liveAnomalyEvents = []
        liveNoiseFloor = nil
        liveCurrentDB = 0

        await SleepNotificationScheduler.deliverImmediateReport(
            sessionID: session.id,
            summary: summary
        )
    }

    func refreshLiveMetrics(currentDB: Float, minDB: Float, leq: Float) {
        guard let session = activeSession else { return }

        if currentDB > 0 {
            liveCurrentDB = currentDB
            intervalPeakDB = max(intervalPeakDB, currentDB)
        }

        let now = Date()
        let warmedUp = now.timeIntervalSince(session.startedAt) >= Self.liveMetricsWarmup
        if warmedUp,
           currentDB > 0,
           now.timeIntervalSince(lastRecentSampleTime) >= Self.recentSampleInterval {
            recentLevelSamples.append(currentDB)
            recentPeakSamples.append(intervalPeakDB > 0 ? intervalPeakDB : currentDB)
            intervalPeakDB = 0
            if recentLevelSamples.count > Self.recentSampleCapacity {
                recentLevelSamples.removeFirst(recentLevelSamples.count - Self.recentSampleCapacity)
                recentPeakSamples.removeFirst(recentPeakSamples.count - Self.recentSampleCapacity)
            }
            lastRecentSampleTime = now
            refreshLiveAnomalyCount(for: session)
        }

        liveNoiseFloor = SleepNoiseAnalyzer.liveNoiseFloor(
            recentLevels: recentLevelSamples,
            persistedLeqSamples: inMemorySamples.map(\.leq)
        )

        if let engine {
            applySleepVADThresholdsIfNeeded(for: session, engine: engine)
        }
    }

    func markReportRead(for sessionID: UUID) {
        guard let modelContext else { return }
        let targetID = sessionID
        let descriptor = FetchDescriptor<SleepNoiseSession>(
            predicate: #Predicate { $0.id == targetID }
        )
        if let session = try? modelContext.fetch(descriptor).first {
            session.isReportRead = true
            try? modelContext.save()
        }
        if SleepMonitorSettingsStore.pendingReportSessionID == sessionID {
            SleepMonitorSettingsStore.pendingReportSessionID = nil
        }
    }

    func presentReport(sessionID: UUID) {
        latestReportSessionID = sessionID
        showReportSheet = true
    }

    func presentPendingReportIfNeeded() {
        guard let pending = SleepMonitorSettingsStore.pendingReportSessionID else { return }
        presentReport(sessionID: pending)
    }

    func dismissReportSheet() {
        showReportSheet = false
    }

    private func restorePendingReportIfNeeded() {
        if let pending = SleepMonitorSettingsStore.pendingReportSessionID {
            latestReportSessionID = pending
        }
    }

    private func handleSleepSampleDue() {
        guard let engine, let modelContext, let session = activeSession else { return }

        let leqSample = engine.leq > 0 ? engine.leq : engine.currentDB
        let peakSample = engine.maxDB > 0 ? engine.maxDB : engine.currentDB
        guard leqSample > 0 else { return }

        SleepMeasurementPersistence.persistSample(
            engine: engine,
            sleepSessionID: session.id,
            in: modelContext
        )

        let sample = (
            timestamp: Date(),
            leq: leqSample,
            peak: peakSample
        )
        inMemorySamples.append(sample)

        let floor = SleepNoiseAnalyzer.noiseFloor(from: inMemorySamples.map(\.leq))

        liveNoiseFloor = SleepNoiseAnalyzer.liveNoiseFloor(
            recentLevels: recentLevelSamples,
            persistedLeqSamples: inMemorySamples.map(\.leq)
        )

        let thresholds = SleepNoiseAnalyzer.dynamicVADThresholds(
            noiseFloor: liveNoiseFloor ?? floor,
            isHighSensitivity: session.isHighSensitivitySession
        )
        engine.applySleepVADThresholds(high: thresholds.high, low: thresholds.low)
        lastVADThresholdUpdate = Date()

        refreshLiveAnomalyCount(for: session)
    }

    private func handleAnomalyClipFinished(_ event: RecordingFinishedEvent) {
        guard activeSession != nil else { return }

        let candidate = SleepAnomalyCandidate(
            timestamp: event.startedAt,
            peakDB: event.peakDB,
            durationSeconds: Float(event.endedAt.timeIntervalSince(event.startedAt))
        )
        let isDuplicate = liveAnomalyEvents.contains {
            abs($0.timestamp.timeIntervalSince(candidate.timestamp)) < 10
        }
        guard !isDuplicate else { return }

        liveAnomalyEvents.append(candidate)
        liveAnomalyCount = max(liveAnomalyCount, liveAnomalyEvents.count)
    }

    private func refreshLiveAnomalyCount(for session: SleepNoiseSession) {
        let floor = liveNoiseFloor
            ?? SleepNoiseAnalyzer.noiseFloor(from: inMemorySamples.map(\.leq))
        guard floor > 0 else { return }

        let liveSamples = liveAnomalyDetectionSamples()
        guard !liveSamples.isEmpty else { return }

        let merged = (inMemorySamples + liveSamples)
            .sorted { $0.timestamp < $1.timestamp }
        let detected = SleepNoiseAnalyzer.detectAnomalies(
            samples: merged,
            noiseFloor: floor,
            referenceDB: NoiseReferenceLimits.residentialNightDB,
            isHighSensitivity: session.isHighSensitivitySession,
            referenceTime: Date(),
            includeOngoing: true,
            minimumDuration: SleepNoiseAnalyzer.liveAnomalyMinimumDuration
        )
        liveAnomalyCount = max(liveAnomalyEvents.count, detected.count)
    }

    private func liveAnomalyDetectionSamples() -> [(timestamp: Date, leq: Float, peak: Float)] {
        guard !recentLevelSamples.isEmpty else { return [] }

        let endingAt = lastRecentSampleTime == .distantPast ? Date() : lastRecentSampleTime
        let start = endingAt.addingTimeInterval(-Double(recentLevelSamples.count) * Self.recentSampleInterval)
        return recentLevelSamples.enumerated().compactMap { index, level in
            guard level > 0 else { return nil }
            let peak = index < recentPeakSamples.count ? recentPeakSamples[index] : level
            return (
                timestamp: start.addingTimeInterval(Double(index) * Self.recentSampleInterval),
                leq: level,
                peak: max(level, peak)
            )
        }
    }

    private func applySleepVADThresholdsIfNeeded(
        for session: SleepNoiseSession,
        engine: NoiseMonitorEngine,
        force: Bool = false
    ) {
        let now = Date()
        if !force, now.timeIntervalSince(lastVADThresholdUpdate) < Self.vadThresholdRefreshInterval {
            return
        }

        let floor = liveNoiseFloor
            ?? SleepNoiseAnalyzer.liveNoiseFloor(
                recentLevels: recentLevelSamples,
                persistedLeqSamples: inMemorySamples.map(\.leq)
            )
            ?? 40
        let thresholds = SleepNoiseAnalyzer.dynamicVADThresholds(
            noiseFloor: floor,
            isHighSensitivity: session.isHighSensitivitySession
        )
        engine.applySleepVADThresholds(high: thresholds.high, low: thresholds.low)
        lastVADThresholdUpdate = now
    }

    func sleepSessionIDForRecording(isSleepAnomalyClip: Bool) -> UUID? {
        if isSleepAnomalyClip {
            return activeSession?.id ?? lastSleepSessionIDForRecording
        }
        return nil
    }

    func noteRecordingSaved(_ session: RecordingSession) {
        guard let modelContext, let sleepID = session.sleepSessionID else { return }
        let targetID = sleepID
        let descriptor = FetchDescriptor<SleepNoiseSession>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let sleepSession = try? modelContext.fetch(descriptor).first else { return }

        if let anomaly = sleepSession.anomalies.min(by: {
            abs($0.timestamp.timeIntervalSince(session.startedAt))
                < abs($1.timestamp.timeIntervalSince(session.startedAt))
        }), abs(anomaly.timestamp.timeIntervalSince(session.startedAt)) < 180 {
            anomaly.recordingSessionID = session.id
            try? modelContext.save()
        }
    }

    private func linkRecordingsToAnomalies(session: SleepNoiseSession) {
        guard let modelContext else { return }
        let sleepID = session.id
        let descriptor = FetchDescriptor<RecordingSession>(
            predicate: #Predicate { $0.sleepSessionID == sleepID }
        )
        let recordings = (try? modelContext.fetch(descriptor)) ?? []
        for anomaly in session.anomalies {
            guard anomaly.recordingSessionID == nil else { continue }
            if let match = recordings.min(by: {
                abs($0.startedAt.timeIntervalSince(anomaly.timestamp))
                    < abs($1.startedAt.timeIntervalSince(anomaly.timestamp))
            }), abs(match.startedAt.timeIntervalSince(anomaly.timestamp)) < 180 {
                anomaly.recordingSessionID = match.id
            }
        }
    }

    private func restoreEnginePreferences(on engine: NoiseMonitorEngine) {
        engine.isHighSensitivityMode = savedHighSensitivity
        engine.voiceActivatedEnabled = savedVoiceActivated
        engine.backgroundMonitoringEnabled = savedBackgroundMonitoring
        engine.persistSettings()
    }

    private func finalEngineSnapshot(from engine: NoiseMonitorEngine) -> (timestamp: Date, leq: Float, peak: Float) {
        let leq = engine.leq > 0 ? engine.leq : engine.currentDB
        let peak = engine.maxDB > 0 ? engine.maxDB : engine.currentDB
        return (Date(), leq, peak)
    }
}
