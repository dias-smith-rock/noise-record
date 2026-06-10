import AVFoundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class VideoEvidenceCoordinator {
    let recorder = VideoNoiseRecorder()
    let locationProvider = LocationEvidenceProvider()

    var isRecording = false
    var isSessionReady = false
    var errorMessage: String?
    var recordingStartedAt: Date?
    var peakDB: Float = 0
    var sessionPeakDB: Float = 0

    func configure() async {
        do {
            try await configureAudioSessionForVideo()
            try recorder.configureSession()
            recorder.startSession()
            locationProvider.requestPermission()
            locationProvider.startUpdating()
            isSessionReady = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncNoise(from engine: NoiseMonitorEngine) {
        let weighting = engine.effectiveWeighting.rawValue
        recorder.dataBridge.update(decibel: engine.currentDB, weighting: weighting)
        if engine.currentDB > sessionPeakDB {
            sessionPeakDB = engine.currentDB
        }
        if isRecording, engine.currentDB > peakDB {
            peakDB = engine.currentDB
        }
    }

    func syncLocation() {
        recorder.dataBridge.updateGPS(
            latitude: locationProvider.latitude,
            longitude: locationProvider.longitude
        )
    }

    func startRecording() {
        guard isSessionReady, !isRecording else { return }
        peakDB = 0
        recordingStartedAt = Date()
        recorder.startRecording()
        isRecording = true
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else { return }
        isRecording = false
        recorder.stopRecording(completion: completion)
    }

    func teardown() {
        locationProvider.stopUpdating()
        recorder.stopSession()
    }

    private func configureAudioSessionForVideo() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }
}

struct VideoEvidenceView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = VideoEvidenceCoordinator()
    @State private var player: AVPlayer?
    @State private var isPreparingRecording = false
    @State private var savedVideoURL: URL?

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProTabHeader(title: "录像", theme: theme)

            ScrollView {
                VStack(spacing: 20) {
                    previewSection
                    controlSection
                    tipsSection
                }
                .padding()
            }
        }
        .proTabBackground(theme: theme)
        .proTabNavigationChrome()
        .task {
            await coordinator.configure()
        }
        .onDisappear {
            coordinator.teardown()
        }
        .onChange(of: engine.currentDB) { _, _ in
            coordinator.syncNoise(from: engine)
        }
        .onChange(of: coordinator.locationProvider.latitude) { _, _ in
            coordinator.syncLocation()
        }
        .alert("错误", isPresented: .constant(coordinator.errorMessage != nil)) {
            Button("确定") { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }

    private var previewSection: some View {
        ZStack(alignment: .bottomLeading) {
            CameraPreviewView(session: coordinator.recorder.captureSessionForPreview)
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
                )

            if coordinator.isRecording {
                HStack(spacing: 8) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("REC")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(coordinator.recorder.dataBridge.overlayDecibelText)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text(Date().formatted(date: .numeric, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(10)
            .background(.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .allowsHitTesting(false)
        }
    }

    private var controlSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProMetricCard(title: "当前分贝", value: String(format: "%.1f", engine.currentDB), theme: theme)
                ProMetricCard(title: "录像峰值", value: String(format: "%.0f", coordinator.peakDB), theme: theme)
                ProMetricCard(
                    title: "GPS",
                    value: coordinator.locationProvider.latitude != nil ? "已定位" : "待授权",
                    theme: theme
                )
            }

            if !engine.isMonitoring || !engine.isHighSensitivityMode {
                Text("开始录像时将自动开启高灵敏噪音监测，分贝水印与实时算法同步。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let savedVideoURL {
                Label("已保存：\(savedVideoURL.lastPathComponent)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                    .multilineTextAlignment(.center)
            }

            Button {
                if coordinator.isRecording {
                    coordinator.stopRecording { result in
                        Task { @MainActor in
                            handleRecordingFinished(result)
                        }
                    }
                } else {
                    Task { await startEvidenceRecording() }
                }
            } label: {
                Label(
                    coordinator.isRecording ? "停止录像并保存" : "开始录像",
                    systemImage: coordinator.isRecording ? "stop.circle.fill" : "video.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(coordinator.isRecording ? .red : theme.accent)
            .disabled(!coordinator.isSessionReady || isPreparingRecording)
        }
    }

    private var tipsSection: some View {
        ProCard(theme: theme) {
            VStack(alignment: .leading, spacing: 8) {
                Label("水印已硬烧录进视频", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.accent)
                Text("每帧画面左下角叠加：实时分贝、毫秒级时间戳、GPS 坐标。输出为 H.264 + AAC 的 .mp4 文件，保存在 Documents/VideoEvidence。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startEvidenceRecording() async {
        guard coordinator.isSessionReady, !coordinator.isRecording else { return }
        isPreparingRecording = true
        savedVideoURL = nil
        defer { isPreparingRecording = false }

        let ready = await engine.ensureMonitoringForVideoEvidence()
        guard ready else {
            coordinator.errorMessage = engine.errorMessage ?? "无法启动噪音监测，请检查麦克风权限。"
            return
        }

        coordinator.syncNoise(from: engine)
        coordinator.syncLocation()
        coordinator.startRecording()
    }

    private func handleRecordingFinished(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let started = coordinator.recordingStartedAt ?? Date()
            let session = VideoEvidenceSession(
                fileName: url.lastPathComponent,
                filePath: EvidenceFileResolver.makeRelativePath(from: url),
                startedAt: started,
                endedAt: Date(),
                peakDB: coordinator.peakDB,
                averageDB: engine.averageDB,
                latitude: coordinator.locationProvider.latitude,
                longitude: coordinator.locationProvider.longitude
            )
            modelContext.insert(session)
            try? modelContext.save()
            savedVideoURL = url
        case .failure(let error):
            coordinator.errorMessage = error.localizedDescription
        }
    }
}
