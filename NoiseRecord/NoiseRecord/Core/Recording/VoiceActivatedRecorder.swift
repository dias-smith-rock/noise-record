import AVFoundation
import Foundation
import UIKit

enum RecordingState: String, Sendable {
    case idle
    case recording
    case coolingDown
}

struct RecordingFinishedEvent: Sendable {
    let fileURL: URL
    let peakDB: Float
    let averageDB: Float
    let startedAt: Date
    let endedAt: Date
    let noiseType: String?
    let segmentIndex: Int
    let latitude: Double?
    let longitude: Double?
    let isSessionRecording: Bool
    let segmentGroupID: UUID?
    let isSleepAnomalyClip: Bool
}

final class VoiceActivatedRecorder: @unchecked Sendable {
    /// Pro users: maximum continuous write duration per monitoring session.
    static let maxSessionDurationPro: TimeInterval = 7200
    /// Free users: maximum continuous write duration per monitoring session.
    static let freeMaxClipDuration: TimeInterval = 180
    /// VAD segment rolling slice limit (10 minutes).
    static let maxVADSegmentDuration: TimeInterval = 600

    /// Legacy alias used by engine configuration.
    static var maxSegmentDuration: TimeInterval { maxSessionDurationPro }

    var highThreshold: Float = 55
    var lowThreshold: Float = 48
    var postRecordingDelay: TimeInterval = 4
    var preBufferDuration: TimeInterval = 1.5
    var voiceActivatedEnabled = false
    var sessionTrackEnabled = true
    var locationSnapshot: () -> (latitude: Double?, longitude: Double?) = { (nil, nil) }

    /// Maximum write duration for the active monitoring session (continuous track).
    var maxClipDuration: TimeInterval = maxSessionDurationPro
    var onClipDurationLimitReached: (() -> Void)?

    /// Reflects VAD track state for UI badges.
    private(set) var state: RecordingState = .idle

    // MARK: - Continuous session track

    private var sessionPcmAccumulator = PCMFrameAccumulator(sampleRate: 44_100)
    private var sessionAudioFile: AVAudioFile?
    private var sessionFormat: AVAudioFormat?

    private var isSessionActive = false
    private var isWritingPaused = false
    private var sessionStartDate: Date?
    private var sessionTimestamp: String?
    private var hasWrittenSessionAudio = false
    private var sessionLastFlushTime: CFAbsoluteTime = 0
    private var didNotifyClipDurationLimit = false
    private var monitoringSessionGroupID: UUID?

    private var sessionTimelineSamples: [VideoNoiseSample] = []
    private var sessionTimelineFrameCount = 0
    private var sessionLastTimelineSampleTime: Double = -1

    // MARK: - VAD segment track

    private var ringBuffer: RingBuffer?
    private var segmentPcmAccumulator = PCMFrameAccumulator(sampleRate: 44_100)
    private var segmentAudioFile: AVAudioFile?
    private var segmentFormat: AVAudioFormat?
    private var coolingDownDeadline: Date?

    private var segmentStartDate: Date?
    private var segmentStartTime: Date?
    private var currentSegmentIndex = 1
    private var sessionTriggerTimestamp: String?
    private var sessionTriggerPeakDB: Int?

    private var segmentPeakDB: Float = 0
    private var segmentDbSum: Float = 0
    private var segmentDbCount = 0
    private var segmentLastFlushTime: CFAbsoluteTime = 0
    private var hasWrittenSegmentAudio = false

    private var segmentTimelineSamples: [VideoNoiseSample] = []
    private var segmentTimelineFrameCount = 0
    private var segmentLastTimelineSampleTime: Double = -1

    // MARK: - Shared

    private var currentNoiseType: String?
    private let flushInterval: CFAbsoluteTime = 0.2
    private let timelineSampleInterval: TimeInterval = 0.1
    private let timelineLock = NSLock()
    private let fileQueue = DispatchQueue(label: "com.noiseapp.recording.file")
    private let appStateLock = NSLock()
    private var isAppInBackground = false
    private var lifecycleObservers: [NSObjectProtocol] = []

    var onRecordingFinished: ((RecordingFinishedEvent) -> Void)?

    init() {
        refreshCachedAppBackgroundState()
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setCachedAppInBackground(true)
            },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setCachedAppInBackground(false)
            },
        ]
    }

    deinit {
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setCachedAppInBackground(_ value: Bool) {
        appStateLock.lock()
        isAppInBackground = value
        appStateLock.unlock()
    }

    private func cachedIsAppInBackground() -> Bool {
        appStateLock.lock()
        defer { appStateLock.unlock() }
        return isAppInBackground
    }

    private func refreshCachedAppBackgroundState() {
        let inBackground: Bool
        if Thread.isMainThread {
            inBackground = UIApplication.shared.applicationState == .background
        } else {
            inBackground = DispatchQueue.main.sync {
                UIApplication.shared.applicationState == .background
            }
        }
        setCachedAppInBackground(inBackground)
    }

    func configure(sampleRate: Double) {
        let capacity = Int(sampleRate * preBufferDuration)
        ringBuffer = RingBuffer(capacity: capacity)
        sessionPcmAccumulator = PCMFrameAccumulator(sampleRate: sampleRate)
        segmentPcmAccumulator = PCMFrameAccumulator(sampleRate: sampleRate)
    }

    func setNoiseType(_ type: String?) {
        currentNoiseType = type
    }

    func beginSession() {
        fileQueue.sync {
            resetAllLocked()
            isSessionActive = true
            isWritingPaused = false
            sessionStartDate = Date()
            sessionTimestamp = Self.timestampString(from: sessionStartDate!)
            monitoringSessionGroupID = UUID()
            didNotifyClipDurationLimit = false
        }
    }

    func process(
        filteredSamples: UnsafePointer<Float>,
        frameLength: Int,
        dbSPL: Float,
        format: AVAudioFormat,
        vadGatedByFilter: Bool = true
    ) {
        if voiceActivatedEnabled {
            ringBuffer?.write(filteredSamples, count: frameLength)
        }

        if isSessionActive, !isWritingPaused, sessionTrackEnabled {
            processSessionTrack(
                filteredSamples: filteredSamples,
                frameLength: frameLength,
                dbSPL: dbSPL,
                format: format
            )
        }

        if voiceActivatedEnabled, vadGatedByFilter {
            processVADTrack(
                filteredSamples: filteredSamples,
                frameLength: frameLength,
                dbSPL: dbSPL,
                format: format
            )
        }
    }

    @discardableResult
    func endSession(
        peakDB: Float,
        averageDB: Float,
        noiseType: String?,
        latitude: Double?,
        longitude: Double?
    ) -> [RecordingFinishedEvent] {
        var events: [RecordingFinishedEvent] = []
        fileQueue.sync {
            guard isSessionActive else { return }
            defer { resetAllLocked() }

            if let segmentEvent = finalizeActiveVADSegmentLocked(emitEvent: false) {
                events.append(segmentEvent)
            }

            try? flushSessionToFileLocked()

            guard let file = sessionAudioFile,
                  let sessionStart = sessionStartDate else {
                return
            }

            let sampleRate = file.processingFormat.sampleRate
            let hasContent = hasWrittenSessionAudio
                || (sampleRate > 0 && file.length > 0)
            guard hasContent else {
                try? FileManager.default.removeItem(at: file.url)
                return
            }

            let url = file.url
            sessionAudioFile = nil
            saveNoiseTimeline(samples: takeSessionTimelineSamples(), for: url)

            events.append(
                RecordingFinishedEvent(
                    fileURL: url,
                    peakDB: peakDB,
                    averageDB: averageDB,
                    startedAt: sessionStart,
                    endedAt: Date(),
                    noiseType: noiseType ?? currentNoiseType,
                    segmentIndex: 0,
                    latitude: latitude,
                    longitude: longitude,
                    isSessionRecording: true,
                    segmentGroupID: monitoringSessionGroupID,
                    isSleepAnomalyClip: false
                )
            )
        }
        state = .idle
        return events
    }

    /// Flush buffered PCM during lifecycle events without ending the session file.
    func emergencyFinalizeForLifecycleEvent() {
        fileQueue.sync {
            if isSessionActive, sessionAudioFile != nil {
                try? flushSessionToFileLocked()
            }

            guard voiceActivatedEnabled,
                  state == .recording || state == .coolingDown,
                  let format = segmentFormat ?? sessionFormat else { return }

            if segmentAudioFile != nil {
                try? finalizeOpenSegmentLocked(emitEvent: true)
            }

            guard state == .recording || state == .coolingDown else { return }

            currentSegmentIndex += 1
            beginNewSegmentTiming()
            try? openSegmentFileLocked(format: format, index: currentSegmentIndex)
        }
    }

    // MARK: - Session track

    private func processSessionTrack(
        filteredSamples: UnsafePointer<Float>,
        frameLength: Int,
        dbSPL: Float,
        format: AVAudioFormat
    ) {
        sessionFormat = format

        var shouldWrite = false
        let logBackgroundRecordingStart = cachedIsAppInBackground()
        fileQueue.sync {
            guard isSessionActive, !isWritingPaused else { return }
            if sessionAudioFile == nil {
                if logBackgroundRecordingStart {
                    AppTelemetry.logBackgroundRecordingStart(peakDB: dbSPL)
                }
                try? openSessionFileLocked(format: format)
            }
            if sessionAudioFile != nil {
                hasWrittenSessionAudio = true
                shouldWrite = true
            }
        }

        guard shouldWrite else { return }

        sessionPcmAccumulator.append(filteredSamples, count: frameLength)
        appendSessionTimelineSample(frameLength: frameLength, dbSPL: dbSPL, format: format)
        flushSessionToFileIfNeeded()

        fileQueue.sync {
            enforceSessionDurationLimitIfNeeded()
        }
    }

    private func enforceSessionDurationLimitIfNeeded() {
        guard isSessionActive, !isWritingPaused,
              let sessionStart = sessionStartDate,
              Date().timeIntervalSince(sessionStart) >= maxClipDuration else { return }

        isWritingPaused = true
        try? flushSessionToFileLocked()

        if !didNotifyClipDurationLimit {
            didNotifyClipDurationLimit = true
            onClipDurationLimitReached?()
        }
    }

    // MARK: - VAD track

    private func processVADTrack(
        filteredSamples: UnsafePointer<Float>,
        frameLength: Int,
        dbSPL: Float,
        format: AVAudioFormat
    ) {
        segmentFormat = format

        switch state {
        case .idle:
            if dbSPL >= highThreshold {
                startVADRecording(format: format, currentDB: dbSPL)
            }
        case .recording:
            updateSegmentMetrics(dbSPL: dbSPL)
            segmentPcmAccumulator.append(filteredSamples, count: frameLength)
            if hasWrittenSegmentAudio {
                appendSegmentTimelineSample(frameLength: frameLength, dbSPL: dbSPL, format: format)
            }
            flushSegmentToFileIfNeeded()
            ensureOpenSegmentFile(format: format)
            rotateSegmentIfNeeded(format: format)

            if dbSPL < lowThreshold {
                state = .coolingDown
                coolingDownDeadline = Date().addingTimeInterval(postRecordingDelay)
            }
        case .coolingDown:
            updateSegmentMetrics(dbSPL: dbSPL)
            segmentPcmAccumulator.append(filteredSamples, count: frameLength)
            if hasWrittenSegmentAudio {
                appendSegmentTimelineSample(frameLength: frameLength, dbSPL: dbSPL, format: format)
            }
            flushSegmentToFileIfNeeded()
            ensureOpenSegmentFile(format: format)
            rotateSegmentIfNeeded(format: format)

            if dbSPL >= highThreshold {
                state = .recording
                coolingDownDeadline = nil
            } else if let deadline = coolingDownDeadline, Date() >= deadline {
                stopVADRecording()
            }
        }
    }

    private func startVADRecording(format: AVAudioFormat, currentDB: Float) {
        guard let ringBuffer else { return }
        if cachedIsAppInBackground() {
            AppTelemetry.logBackgroundRecordingStart(peakDB: currentDB)
        }

        let triggerTime = Date()
        state = .recording
        coolingDownDeadline = nil
        currentSegmentIndex = 1
        sessionTriggerTimestamp = Self.timestampString(from: triggerTime)
        sessionTriggerPeakDB = Int(currentDB)
        beginNewSegmentTiming(at: triggerTime)
        segmentPeakDB = currentDB
        segmentDbSum = currentDB
        segmentDbCount = 1

        let preSamples = ringBuffer.readAll()

        fileQueue.sync {
            do {
                try openSegmentFileLocked(format: format, index: currentSegmentIndex)
                if !preSamples.isEmpty {
                    segmentPcmAccumulator.appendFromArray(preSamples)
                    hasWrittenSegmentAudio = true
                    segmentTimelineFrameCount += preSamples.count
                }
                try flushSegmentToFileLocked()
            } catch {
                resetVADLocked()
            }
        }

        if segmentAudioFile == nil {
            resetVADState()
        }
    }

    private func stopVADRecording() {
        guard state != .idle else { return }

        fileQueue.sync {
            if segmentAudioFile != nil {
                try? finalizeOpenSegmentLocked(emitEvent: true)
            }
        }
        resetVADState()
    }

    @discardableResult
    private func finalizeActiveVADSegmentLocked(emitEvent: Bool) -> RecordingFinishedEvent? {
        guard state == .recording || state == .coolingDown else { return nil }
        let event = segmentAudioFile != nil
            ? try? finalizeOpenSegmentLocked(emitEvent: emitEvent)
            : nil
        resetVADLocked()
        return event
    }

    private func resetVADState() {
        fileQueue.sync {
            resetVADLocked()
        }
        state = .idle
    }

    private func updateSegmentMetrics(dbSPL: Float) {
        segmentPeakDB = max(segmentPeakDB, dbSPL)
        segmentDbSum += dbSPL
        segmentDbCount += 1
    }

    private func beginNewSegmentTiming(at date: Date = Date()) {
        segmentStartTime = date
        segmentStartDate = date
        segmentPeakDB = 0
        segmentDbSum = 0
        segmentDbCount = 0
        resetSegmentTimelineLocked()
    }

    private func rotateSegmentIfNeeded(format: AVAudioFormat) {
        guard state == .recording || state == .coolingDown else { return }
        guard let segmentStart = segmentStartTime,
              Date().timeIntervalSince(segmentStart) >= Self.maxVADSegmentDuration else { return }

        fileQueue.sync {
            guard state == .recording || state == .coolingDown,
                  let activeSegmentStart = segmentStartTime,
                  Date().timeIntervalSince(activeSegmentStart) >= Self.maxVADSegmentDuration,
                  segmentAudioFile != nil else { return }
            try? rotateSegmentLocked(format: format)
        }
    }

    private func rotateSegmentLocked(format: AVAudioFormat) throws {
        var reopened = false
        defer {
            if !reopened, segmentAudioFile == nil, state == .recording || state == .coolingDown {
                try? openSegmentFileLocked(format: format, index: currentSegmentIndex)
            }
        }

        try finalizeOpenSegmentLocked(emitEvent: true)
        currentSegmentIndex += 1
        beginNewSegmentTiming()
        try openSegmentFileLocked(format: format, index: currentSegmentIndex)
        reopened = segmentAudioFile != nil
    }

    private func ensureOpenSegmentFile(format: AVAudioFormat) {
        guard segmentAudioFile == nil, state == .recording || state == .coolingDown else { return }

        fileQueue.sync {
            guard segmentAudioFile == nil, state == .recording || state == .coolingDown else { return }
            if sessionTriggerTimestamp == nil {
                let now = Date()
                sessionTriggerTimestamp = Self.timestampString(from: now)
                if sessionTriggerPeakDB == nil {
                    sessionTriggerPeakDB = Int(segmentPeakDB.rounded())
                }
                if segmentStartDate == nil {
                    beginNewSegmentTiming(at: now)
                }
            }
            try? openSegmentFileLocked(format: format, index: currentSegmentIndex)
        }
    }

    // MARK: - File I/O (fileQueue only)

    private func recordingsDirectory() throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static let sessionFilePrefix = "F_"
    static let segmentFilePrefix = "S_"

    static func makeSessionFileName(timestamp: String) -> String {
        "\(sessionFilePrefix)\(timestamp).m4a"
    }

    static func makeSegmentFileName(timestamp: String, index: Int) -> String {
        if index <= 1 {
            return "\(segmentFilePrefix)\(timestamp).m4a"
        }
        return "\(segmentFilePrefix)\(timestamp)_p\(index).m4a"
    }

    private func openSessionFileLocked(format: AVAudioFormat) throws {
        guard let timestamp = sessionTimestamp else {
            throw VoiceRecorderError.missingSessionMetadata
        }

        let fileName = Self.makeSessionFileName(timestamp: timestamp)
        let fileURL = try recordingsDirectory().appendingPathComponent(fileName)
        sessionAudioFile = try AVAudioFile(forWriting: fileURL, settings: aacSettings(sampleRate: format.sampleRate))
        sessionFormat = format
    }

    private func openSegmentFileLocked(format: AVAudioFormat, index: Int) throws {
        guard let fileName = segmentFileName(index: index) else {
            throw VoiceRecorderError.missingSessionMetadata
        }

        let fileURL = try recordingsDirectory().appendingPathComponent(fileName)
        segmentAudioFile = try AVAudioFile(forWriting: fileURL, settings: aacSettings(sampleRate: format.sampleRate))
        segmentFormat = format
        hasWrittenSegmentAudio = true
    }

    private func segmentFileName(index: Int) -> String? {
        guard let timestamp = sessionTriggerTimestamp else { return nil }
        return Self.makeSegmentFileName(timestamp: timestamp, index: index)
    }

    @discardableResult
    private func finalizeOpenSegmentLocked(emitEvent: Bool) throws -> RecordingFinishedEvent? {
        guard let file = segmentAudioFile,
              let segmentStart = segmentStartDate else {
            segmentAudioFile = nil
            return nil
        }

        try flushSegmentToFileLocked()
        let url = file.url
        segmentAudioFile = nil
        saveNoiseTimeline(samples: takeSegmentTimelineSamples(), for: url)

        let location = locationSnapshot()
        let event = RecordingFinishedEvent(
            fileURL: url,
            peakDB: segmentPeakDB,
            averageDB: segmentDbCount > 0 ? segmentDbSum / Float(segmentDbCount) : 0,
            startedAt: segmentEventStartDate(fallback: segmentStart),
            endedAt: Date(),
            noiseType: currentNoiseType,
            segmentIndex: currentSegmentIndex,
            latitude: location.latitude,
            longitude: location.longitude,
            isSessionRecording: false,
            segmentGroupID: monitoringSessionGroupID,
            isSleepAnomalyClip: false
        )
        if emitEvent {
            onRecordingFinished?(event)
        }
        return event
    }

    private func aacSettings(sampleRate: Double) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
    }

    private func flushSessionToFileIfNeeded() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - sessionLastFlushTime >= flushInterval else { return }
        sessionLastFlushTime = now
        fileQueue.async { [weak self] in
            try? self?.flushSessionToFileLocked()
        }
    }

    private func flushSegmentToFileIfNeeded() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - segmentLastFlushTime >= flushInterval else { return }
        segmentLastFlushTime = now
        fileQueue.async { [weak self] in
            try? self?.flushSegmentToFileLocked()
        }
    }

    private func flushSessionToFileLocked() throws {
        guard let file = sessionAudioFile, let format = sessionFormat else { return }
        try sessionPcmAccumulator.drain(into: file, format: format)
    }

    private func flushSegmentToFileLocked() throws {
        guard let file = segmentAudioFile, let format = segmentFormat else { return }
        try segmentPcmAccumulator.drain(into: file, format: format)
    }

    // MARK: - Timeline

    private func appendSessionTimelineSample(frameLength: Int, dbSPL: Float, format: AVAudioFormat) {
        timelineLock.lock()
        defer { timelineLock.unlock() }

        sessionTimelineFrameCount += frameLength
        let relativeTime = Double(sessionTimelineFrameCount) / format.sampleRate
        guard relativeTime >= 0 else { return }
        guard sessionLastTimelineSampleTime < 0
            || relativeTime - sessionLastTimelineSampleTime >= timelineSampleInterval else { return }

        sessionTimelineSamples.append(VideoNoiseSample(time: relativeTime, decibel: dbSPL))
        sessionLastTimelineSampleTime = relativeTime
    }

    private func appendSegmentTimelineSample(frameLength: Int, dbSPL: Float, format: AVAudioFormat) {
        timelineLock.lock()
        defer { timelineLock.unlock() }

        segmentTimelineFrameCount += frameLength
        let relativeTime = Double(segmentTimelineFrameCount) / format.sampleRate
        guard relativeTime >= 0 else { return }
        guard segmentLastTimelineSampleTime < 0
            || relativeTime - segmentLastTimelineSampleTime >= timelineSampleInterval else { return }

        segmentTimelineSamples.append(VideoNoiseSample(time: relativeTime, decibel: dbSPL))
        segmentLastTimelineSampleTime = relativeTime
    }

    private func takeSessionTimelineSamples() -> [VideoNoiseSample] {
        timelineLock.lock()
        let samples = sessionTimelineSamples
        timelineLock.unlock()
        return samples
    }

    private func takeSegmentTimelineSamples() -> [VideoNoiseSample] {
        timelineLock.lock()
        let samples = segmentTimelineSamples
        timelineLock.unlock()
        return samples
    }

    private func resetSegmentTimelineLocked() {
        segmentTimelineSamples.removeAll()
        segmentLastTimelineSampleTime = -1
        segmentTimelineFrameCount = 0
    }

    private func saveNoiseTimeline(samples: [VideoNoiseSample], for url: URL) {
        guard !samples.isEmpty else { return }

        var timeline = VideoNoiseTimeline(
            weighting: "dB\(DeviceCalibrationStore.weightingType.rawValue)",
            samples: samples,
            source: .live,
            normalized: false
        )

        if let file = try? AVAudioFile(forReading: url) {
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else {
                try? VideoNoiseTimelineStore.save(timeline, for: url)
                return
            }
            let fileDuration = Double(file.length) / sampleRate
            if fileDuration > 0, let normalized = timeline.normalized(to: fileDuration, source: .live) {
                timeline = normalized
            }
        }

        try? VideoNoiseTimelineStore.save(timeline, for: url)
    }

    // MARK: - Reset

    private func resetAllLocked() {
        resetVADLocked()
        state = .idle
        sessionAudioFile = nil
        sessionFormat = nil
        isSessionActive = false
        isWritingPaused = false
        sessionStartDate = nil
        sessionTimestamp = nil
        hasWrittenSessionAudio = false
        sessionLastFlushTime = 0
        didNotifyClipDurationLimit = false
        monitoringSessionGroupID = nil
        sessionTimelineSamples.removeAll()
        sessionLastTimelineSampleTime = -1
        sessionTimelineFrameCount = 0
        sessionPcmAccumulator.reset()
    }

    private func resetVADLocked() {
        state = .idle
        segmentAudioFile = nil
        segmentFormat = nil
        coolingDownDeadline = nil
        segmentStartDate = nil
        segmentStartTime = nil
        currentSegmentIndex = 1
        sessionTriggerTimestamp = nil
        sessionTriggerPeakDB = nil
        segmentPeakDB = 0
        segmentDbSum = 0
        segmentDbCount = 0
        segmentLastFlushTime = 0
        hasWrittenSegmentAudio = false
        resetSegmentTimelineLocked()
        segmentPcmAccumulator.reset()
    }

    private func segmentEventStartDate(fallback: Date) -> Date {
        if currentSegmentIndex == 1,
           let timestamp = sessionTriggerTimestamp,
           let triggerDate = Self.date(fromTimestamp: timestamp) {
            return triggerDate
        }
        return fallback
    }

    private static func date(fromTimestamp timestamp: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.date(from: timestamp)
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

private enum VoiceRecorderError: Error {
    case missingSessionMetadata
}
