import AVFoundation
import Foundation

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
}

final class VoiceActivatedRecorder: @unchecked Sendable {
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
    private var recordingStartDate: Date?
    private var peakDB: Float = 0
    private var dbSum: Float = 0
    private var dbCount: Int = 0
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
            peakDB = max(peakDB, dbSPL)
            dbSum += dbSPL
            dbCount += 1
            pcmAccumulator.append(filteredSamples, count: frameLength)
            flushToFileIfNeeded()

            if dbSPL < lowThreshold {
                state = .coolingDown
                coolingDownDeadline = Date().addingTimeInterval(postRecordingDelay)
            }
        case .coolingDown:
            peakDB = max(peakDB, dbSPL)
            dbSum += dbSPL
            dbCount += 1
            pcmAccumulator.append(filteredSamples, count: frameLength)
            flushToFileIfNeeded()

            if dbSPL >= highThreshold {
                state = .recording
                coolingDownDeadline = nil
            } else if let deadline = coolingDownDeadline, Date() >= deadline {
                stopRecording()
            }
        }
    }

    private func startRecording(format: AVAudioFormat, currentDB: Float) {
        guard let ringBuffer else { return }
        state = .recording
        recordingStartDate = Date()
        peakDB = currentDB
        dbSum = currentDB
        dbCount = 1
        coolingDownDeadline = nil

        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "\(timestamp)_\(Int(currentDB))dB.m4a"
        let fileURL = recordingsDir.appendingPathComponent(fileName)

        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ])
            recordingFormat = format

            let preSamples = ringBuffer.readAll()
            if !preSamples.isEmpty {
                pcmAccumulator.appendFromArray(preSamples)
            }
            flushToFile()
        } catch {
            state = .idle
            audioFile = nil
        }
    }

    private func flushToFileIfNeeded() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFlushTime >= flushInterval else { return }
        lastFlushTime = now
        flushToFile()
    }

    private func flushToFile() {
        fileQueue.async { [weak self] in
            guard let self, let file = self.audioFile, let format = self.recordingFormat else { return }
            try? self.pcmAccumulator.drain(into: file, format: format)
        }
    }

    private func stopRecording() {
        guard let fileURL = audioFile?.url,
              let startDate = recordingStartDate else {
            resetSession()
            return
        }

        fileQueue.sync { [weak self] in
            guard let self, let file = self.audioFile, let format = self.recordingFormat else { return }
            try? self.pcmAccumulator.drain(into: file, format: format)
        }

        let event = RecordingFinishedEvent(
            fileURL: fileURL,
            peakDB: peakDB,
            averageDB: dbCount > 0 ? dbSum / Float(dbCount) : 0,
            startedAt: startDate,
            endedAt: Date(),
            noiseType: currentNoiseType
        )
        onRecordingFinished?(event)
        resetSession()
    }

    private func resetSession() {
        state = .idle
        audioFile = nil
        coolingDownDeadline = nil
        recordingStartDate = nil
        peakDB = 0
        dbSum = 0
        dbCount = 0
        lastFlushTime = 0
        pcmAccumulator.reset()
    }

    func forceStop() {
        if state == .recording || state == .coolingDown {
            stopRecording()
        }
    }
}
