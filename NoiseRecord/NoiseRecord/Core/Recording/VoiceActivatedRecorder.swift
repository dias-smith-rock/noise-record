import AVFoundation
import Foundation
import UIKit

enum RecordingState: String, Sendable {
    case idle
    case recording
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
}

final class VoiceActivatedRecorder: @unchecked Sendable {
    /// Pro users: maximum continuous write duration per monitoring session.
    static let maxSessionDurationPro: TimeInterval = 7200
    /// Free users: maximum continuous write duration per monitoring session.
    static let freeMaxClipDuration: TimeInterval = 180

    /// Legacy alias used by engine configuration.
    static var maxSegmentDuration: TimeInterval { maxSessionDurationPro }

    /// Maximum write duration for the active monitoring session.
    var maxClipDuration: TimeInterval = maxSessionDurationPro
    var onClipDurationLimitReached: (() -> Void)?

    private(set) var state: RecordingState = .idle
    private var pcmAccumulator = PCMFrameAccumulator(sampleRate: 44_100)
    private var audioFile: AVAudioFile?
    private var recordingFormat: AVAudioFormat?

    private var isSessionActive = false
    private var isWritingPaused = false
    private var sessionStartDate: Date?
    private var sessionTimestamp: String?
    private var hasWrittenAudio = false
    private var currentNoiseType: String?
    private var lastFlushTime: CFAbsoluteTime = 0
    private let flushInterval: CFAbsoluteTime = 0.2
    private var didNotifyClipDurationLimit = false

    private var noiseTimelineSamples: [VideoNoiseSample] = []
    private var lastTimelineSampleTime: Double = -1
    private var timelineFrameCount = 0
    private let timelineSampleInterval: TimeInterval = 0.1
    private let timelineLock = NSLock()

    private let fileQueue = DispatchQueue(label: "com.noiseapp.recording.file")
    var onRecordingFinished: ((RecordingFinishedEvent) -> Void)?

    func configure(sampleRate: Double) {
        pcmAccumulator = PCMFrameAccumulator(sampleRate: sampleRate)
    }

    func setNoiseType(_ type: String?) {
        currentNoiseType = type
    }

    func beginSession() {
        fileQueue.sync {
            resetSessionLocked()
            isSessionActive = true
            isWritingPaused = false
            sessionStartDate = Date()
            sessionTimestamp = Self.timestampString(from: sessionStartDate!)
            didNotifyClipDurationLimit = false
        }
    }

    func process(
        filteredSamples: UnsafePointer<Float>,
        frameLength: Int,
        dbSPL: Float,
        format: AVAudioFormat
    ) {
        guard isSessionActive, !isWritingPaused else { return }

        recordingFormat = format

        fileQueue.sync {
            guard isSessionActive, !isWritingPaused else { return }
            if audioFile == nil {
                if UIApplication.shared.applicationState == .background {
                    AppTelemetry.logBackgroundRecordingStart(peakDB: dbSPL)
                }
                try? openSessionFileLocked(format: format)
            }
            if audioFile != nil {
                state = .recording
                hasWrittenAudio = true
            }
        }

        pcmAccumulator.append(filteredSamples, count: frameLength)
        appendTimelineSample(frameLength: frameLength, dbSPL: dbSPL, format: format)
        flushToFileIfNeeded()

        fileQueue.sync {
            enforceSessionDurationLimitIfNeeded()
        }
    }

    func endSession(
        peakDB: Float,
        averageDB: Float,
        noiseType: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        fileQueue.sync {
            guard isSessionActive else { return }
            defer { resetSessionLocked() }

            guard hasWrittenAudio, audioFile != nil else {
                if let url = audioFile?.url {
                    try? FileManager.default.removeItem(at: url)
                }
                return
            }

            try? flushToFileLocked()
            guard let file = audioFile,
                  let sessionStart = sessionStartDate else { return }

            let url = file.url
            audioFile = nil
            saveNoiseTimeline(for: url)

            let event = RecordingFinishedEvent(
                fileURL: url,
                peakDB: peakDB,
                averageDB: averageDB,
                startedAt: sessionStart,
                endedAt: Date(),
                noiseType: noiseType ?? currentNoiseType,
                segmentIndex: 1,
                latitude: latitude,
                longitude: longitude
            )
            onRecordingFinished?(event)
        }
        state = .idle
    }

    /// Flush buffered PCM during lifecycle events without ending the session file.
    func emergencyFinalizeForLifecycleEvent() {
        fileQueue.sync {
            guard isSessionActive, audioFile != nil else { return }
            try? flushToFileLocked()
        }
    }

    // MARK: - Session duration limit

    private func enforceSessionDurationLimitIfNeeded() {
        guard isSessionActive, !isWritingPaused,
              let sessionStart = sessionStartDate,
              Date().timeIntervalSince(sessionStart) >= maxClipDuration else { return }

        isWritingPaused = true
        state = .idle
        try? flushToFileLocked()

        if !didNotifyClipDurationLimit {
            didNotifyClipDurationLimit = true
            onClipDurationLimitReached?()
        }
    }

    // MARK: - File I/O (fileQueue only)

    private func recordingsDirectory() throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func makeSessionFileName(timestamp: String) -> String {
        "\(timestamp)_session.m4a"
    }

    /// Legacy helper kept for tests migrating from segment naming.
    static func makeSegmentFileName(timestamp: String, peakDB: Int, index: Int) -> String {
        if index <= 1 {
            return makeSessionFileName(timestamp: timestamp)
        }
        return "\(timestamp)_session_part\(index).m4a"
    }

    private func openSessionFileLocked(format: AVAudioFormat) throws {
        guard let timestamp = sessionTimestamp else {
            throw VoiceRecorderError.missingSessionMetadata
        }

        let fileName = Self.makeSessionFileName(timestamp: timestamp)
        let fileURL = try recordingsDirectory().appendingPathComponent(fileName)
        audioFile = try AVAudioFile(forWriting: fileURL, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
        recordingFormat = format
    }

    private func flushToFileIfNeeded() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFlushTime >= flushInterval else { return }
        lastFlushTime = now
        flushToFile()
    }

    private func flushToFile() {
        fileQueue.async { [weak self] in
            try? self?.flushToFileLocked()
        }
    }

    private func flushToFileLocked() throws {
        guard let file = audioFile, let format = recordingFormat else { return }
        try pcmAccumulator.drain(into: file, format: format)
    }

    private func appendTimelineSample(frameLength: Int, dbSPL: Float, format: AVAudioFormat) {
        timelineLock.lock()
        defer { timelineLock.unlock() }

        timelineFrameCount += frameLength
        let relativeTime = Double(timelineFrameCount) / format.sampleRate
        guard relativeTime >= 0 else { return }
        guard lastTimelineSampleTime < 0
            || relativeTime - lastTimelineSampleTime >= timelineSampleInterval else { return }

        noiseTimelineSamples.append(VideoNoiseSample(time: relativeTime, decibel: dbSPL))
        lastTimelineSampleTime = relativeTime
    }

    private func saveNoiseTimeline(for url: URL) {
        timelineLock.lock()
        let samples = noiseTimelineSamples
        timelineLock.unlock()

        guard !samples.isEmpty else { return }
        let timeline = VideoNoiseTimeline(
            weighting: "dB\(DeviceCalibrationStore.weightingType.rawValue)",
            samples: samples
        )
        try? VideoNoiseTimelineStore.save(timeline, for: url)
    }

    private func resetSessionLocked() {
        state = .idle
        audioFile = nil
        recordingFormat = nil
        isSessionActive = false
        isWritingPaused = false
        sessionStartDate = nil
        sessionTimestamp = nil
        hasWrittenAudio = false
        lastFlushTime = 0
        didNotifyClipDurationLimit = false
        timelineLock.lock()
        noiseTimelineSamples.removeAll()
        lastTimelineSampleTime = -1
        timelineFrameCount = 0
        timelineLock.unlock()
        pcmAccumulator.reset()
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
