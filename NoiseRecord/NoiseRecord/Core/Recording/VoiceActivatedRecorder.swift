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
}

final class VoiceActivatedRecorder: @unchecked Sendable {
    /// 单段安全落盘阈值（10 分钟），超时滚动切片。
    static let maxSegmentDuration: TimeInterval = 600

    var highThreshold: Float = 55
    var lowThreshold: Float = 48
    var postRecordingDelay: TimeInterval = 4
    var preBufferDuration: TimeInterval = 1.5

    private(set) var state: RecordingState = .idle
    private var ringBuffer: RingBuffer?
    private var pcmAccumulator = PCMFrameAccumulator(sampleRate: 44_100)
    private var audioFile: AVAudioFile?
    private var recordingFormat: AVAudioFormat?
    private var coolingDownDeadline: Date?

    /// 本次声控触发会话的起始时间（跨分段不变）。
    private var recordingStartDate: Date?
    /// 当前滚动分段的起始时间。
    private var segmentStartTime: Date?
    /// 当前分段在触发序列中的序号（从 1 起）。
    private var currentSegmentIndex: Int = 1
    /// 触发时刻文件名时间戳（跨分段共享）。
    private var sessionTriggerTimestamp: String?
    /// 触发峰值 dB（文件名后缀，跨分段共享）。
    private var sessionTriggerPeakDB: Int?

    private var segmentPeakDB: Float = 0
    private var segmentDbSum: Float = 0
    private var segmentDbCount: Int = 0
    private var currentNoiseType: String?
    private var lastFlushTime: CFAbsoluteTime = 0
    private let flushInterval: CFAbsoluteTime = 0.2

    private let fileQueue = DispatchQueue(label: "com.noiseapp.recording.file")
    var onRecordingFinished: ((RecordingFinishedEvent) -> Void)?

    func configure(sampleRate: Double) {
        let capacity = Int(sampleRate * preBufferDuration)
        ringBuffer = RingBuffer(capacity: capacity)
        pcmAccumulator = PCMFrameAccumulator(sampleRate: sampleRate)
    }

    func setNoiseType(_ type: String?) {
        currentNoiseType = type
    }

    func process(
        filteredSamples: UnsafePointer<Float>,
        frameLength: Int,
        dbSPL: Float,
        format: AVAudioFormat
    ) {
        recordingFormat = format
        ringBuffer?.write(filteredSamples, count: frameLength)

        switch state {
        case .idle:
            if dbSPL >= highThreshold {
                startRecording(format: format, currentDB: dbSPL)
            }
        case .recording:
            updateSegmentMetrics(dbSPL: dbSPL)
            pcmAccumulator.append(filteredSamples, count: frameLength)
            flushToFileIfNeeded()
            ensureOpenSegmentFile(format: format)
            rotateSegmentIfNeeded(format: format)

            if dbSPL < lowThreshold {
                state = .coolingDown
                coolingDownDeadline = Date().addingTimeInterval(postRecordingDelay)
            }
        case .coolingDown:
            updateSegmentMetrics(dbSPL: dbSPL)
            pcmAccumulator.append(filteredSamples, count: frameLength)
            flushToFileIfNeeded()
            ensureOpenSegmentFile(format: format)
            rotateSegmentIfNeeded(format: format)

            if dbSPL >= highThreshold {
                state = .recording
                coolingDownDeadline = nil
            } else if let deadline = coolingDownDeadline, Date() >= deadline {
                stopRecording()
            }
        }
    }

    /// 电话切入、进后台等生命周期事件：优先落盘当前分段并无缝续开新流（不停止 tap）。
    func emergencyFinalizeForLifecycleEvent() {
        fileQueue.sync {
            guard state == .recording || state == .coolingDown else { return }
            guard let format = recordingFormat else { return }

            if audioFile != nil {
                try? finalizeOpenSegmentLocked(emitEvent: true)
            }

            guard state == .recording || state == .coolingDown else { return }

            currentSegmentIndex += 1
            beginNewSegmentTiming()
            try? openSegmentFileLocked(format: format, index: currentSegmentIndex)
        }
    }

    func forceStop() {
        if state == .recording || state == .coolingDown {
            stopRecording()
        }
    }

    // MARK: - Session lifecycle

    private func startRecording(format: AVAudioFormat, currentDB: Float) {
        guard let ringBuffer else { return }
        if UIApplication.shared.applicationState == .background {
            AppTelemetry.logBackgroundRecordingStart(peakDB: currentDB)
        }

        let now = Date()
        state = .recording
        recordingStartDate = now
        coolingDownDeadline = nil
        currentSegmentIndex = 1
        sessionTriggerTimestamp = Self.timestampString(from: now)
        sessionTriggerPeakDB = Int(currentDB)
        beginNewSegmentTiming(at: now)
        segmentPeakDB = currentDB
        segmentDbSum = currentDB
        segmentDbCount = 1

        let preSamples = ringBuffer.readAll()

        fileQueue.sync {
            do {
                try openSegmentFileLocked(format: format, index: currentSegmentIndex)
                if !preSamples.isEmpty {
                    pcmAccumulator.appendFromArray(preSamples)
                }
                try flushToFileLocked()
            } catch {
                resetSessionLocked()
            }
        }

        if audioFile == nil {
            resetSession()
        }
    }

    private func stopRecording() {
        guard state != .idle else { return }

        fileQueue.sync {
            if audioFile != nil {
                try? finalizeOpenSegmentLocked(emitEvent: true)
            }
        }
        resetSession()
    }

    private func resetSession() {
        fileQueue.sync {
            resetSessionLocked()
        }
    }

    private func resetSessionLocked() {
        state = .idle
        audioFile = nil
        recordingFormat = nil
        coolingDownDeadline = nil
        recordingStartDate = nil
        segmentStartTime = nil
        segmentStartDate = nil
        currentSegmentIndex = 1
        sessionTriggerTimestamp = nil
        sessionTriggerPeakDB = nil
        segmentPeakDB = 0
        segmentDbSum = 0
        segmentDbCount = 0
        lastFlushTime = 0
        pcmAccumulator.reset()
    }

    // MARK: - Segment metrics

    private var segmentStartDate: Date?

    private func beginNewSegmentTiming(at date: Date = Date()) {
        segmentStartTime = date
        segmentStartDate = date
        segmentPeakDB = 0
        segmentDbSum = 0
        segmentDbCount = 0
    }

    private func updateSegmentMetrics(dbSPL: Float) {
        segmentPeakDB = max(segmentPeakDB, dbSPL)
        segmentDbSum += dbSPL
        segmentDbCount += 1
    }

    // MARK: - Rolling segment rotation

    private func rotateSegmentIfNeeded(format: AVAudioFormat) {
        guard state == .recording || state == .coolingDown else { return }
        guard let segmentStart = segmentStartTime,
              Date().timeIntervalSince(segmentStart) >= Self.maxSegmentDuration else { return }

        fileQueue.sync {
            guard state == .recording || state == .coolingDown,
                  let activeSegmentStart = segmentStartTime,
                  Date().timeIntervalSince(activeSegmentStart) >= Self.maxSegmentDuration,
                  audioFile != nil else { return }
            try? rotateSegmentLocked(format: format)
        }
    }

    private func rotateSegmentLocked(format: AVAudioFormat) throws {
        var reopened = false
        defer {
            if !reopened, audioFile == nil, state == .recording || state == .coolingDown {
                try? openSegmentFileLocked(format: format, index: currentSegmentIndex)
            }
        }

        try finalizeOpenSegmentLocked(emitEvent: true)
        currentSegmentIndex += 1
        beginNewSegmentTiming()
        try openSegmentFileLocked(format: format, index: currentSegmentIndex)
        reopened = audioFile != nil
    }

    private func ensureOpenSegmentFile(format: AVAudioFormat) {
        guard audioFile == nil, state == .recording || state == .coolingDown else { return }

        fileQueue.sync {
            guard audioFile == nil, state == .recording || state == .coolingDown else { return }
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

    private func segmentFileName(index: Int) -> String? {
        guard let timestamp = sessionTriggerTimestamp,
              let peakDB = sessionTriggerPeakDB else { return nil }
        return Self.makeSegmentFileName(timestamp: timestamp, peakDB: peakDB, index: index)
    }

    static func makeSegmentFileName(timestamp: String, peakDB: Int, index: Int) -> String {
        if index <= 1 {
            return "\(timestamp)_\(peakDB)dB.m4a"
        }
        return "\(timestamp)_\(peakDB)dB_part\(index).m4a"
    }

    private func openSegmentFileLocked(format: AVAudioFormat, index: Int) throws {
        guard let fileName = segmentFileName(index: index) else {
            throw VoiceRecorderError.missingSessionMetadata
        }

        let fileURL = try recordingsDirectory().appendingPathComponent(fileName)
        audioFile = try AVAudioFile(forWriting: fileURL, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
        recordingFormat = format
    }

    @discardableResult
    private func finalizeOpenSegmentLocked(emitEvent: Bool) throws -> URL? {
        guard let file = audioFile,
              let format = recordingFormat,
              let segmentStart = segmentStartDate else {
            audioFile = nil
            return nil
        }

        try flushToFileLocked()
        let url = file.url
        audioFile = nil

        guard emitEvent else { return url }

        let event = RecordingFinishedEvent(
            fileURL: url,
            peakDB: segmentPeakDB,
            averageDB: segmentDbCount > 0 ? segmentDbSum / Float(segmentDbCount) : 0,
            startedAt: segmentStart,
            endedAt: Date(),
            noiseType: currentNoiseType,
            segmentIndex: currentSegmentIndex
        )
        onRecordingFinished?(event)
        return url
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

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

private enum VoiceRecorderError: Error {
    case missingSessionMetadata
}
