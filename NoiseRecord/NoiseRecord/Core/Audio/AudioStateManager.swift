import AVFoundation
import Foundation

/// 应用级音频业务状态：监测、播放、播放结束后的挂起待机。
enum AppAudioState: Equatable, Sendable {
    /// 正在运行噪音监测 / 声控录音采集链路。
    case monitoring
    /// 正在播放本地录音或视频；监测引擎已完全停止。
    case playing
    /// 播放已结束，等待用户手动恢复监测（不自动重启麦克风）。
    case idle
}

/// 统一管理「监测 ↔ 播放 ↔ 挂起待机」状态机，避免 AVAudioEngine 与播放器争抢 AVAudioSession。
@MainActor
@Observable
final class AudioStateManager {
    /// 当前对外状态，供 SwiftUI 绑定。
    private(set) var appAudioState: AppAudioState

    private let engine: NoiseMonitorEngine

    init(engine: NoiseMonitorEngine) {
        self.engine = engine
        self.appAudioState = engine.isMonitoring ? .monitoring : .idle
    }

    /// 是否允许 App 生命周期回调（进入后台/回前台）自动恢复监测管道。
    var allowsAutomaticMonitoringRecovery: Bool {
        appAudioState == .monitoring
    }

    // MARK: - 动作一：准备播放

    /// 用户点击播放录音/视频前调用：完全停止监测，并切换到纯播放会话（大扬声器）。
    func prepareAndStartPlayback() throws {
        // 1. 完全停止监测引擎（removeTap + stop），并清零仪表读数。
        engine.suspendMonitoringForPlayback()

        // 2. 切换为纯播放模式，走系统默认播放链路（含 AGC/EQ），音量更饱满。
        try AudioSessionManager.configureForExclusivePlayback()

        // 3. 进入播放态；后续由播放器组件开始实际播放。
        appAudioState = .playing
    }

    // MARK: - 动作二：播放结束

    /// 播放自然结束、用户点停止、或关闭播放器时调用；**不会**自动重启监测。
    func handlePlaybackFinished() {
        appAudioState = .idle
        engine.resetStatistics()
    }

    // MARK: - 动作三：手动恢复监测

    /// 用户在 UI 上显式点击「恢复监测 / 开始监测」时调用。
    func manuallyResumeMonitoring() async {
        guard appAudioState != .playing else { return }

        if engine.isMonitoring {
            appAudioState = .monitoring
            return
        }

        do {
            try reconfigureMeasurementSession()
            await engine.requestPermissionAndStart()
            if engine.isMonitoring {
                appAudioState = .monitoring
                AppTelemetry.logMonitorStart()
            }
        } catch {
            appAudioState = .idle
        }
    }

    /// 用户在监测页主动停止监测（非播放场景）。
    func stopMonitoringManually() {
        engine.requestMonitoringStopWithSavePrompt()
        appAudioState = .idle
    }

    /// 监测引擎启动成功后同步状态（例如 Dashboard 原有启动路径）。
    func noteMonitoringStarted() {
        guard engine.isMonitoring else { return }
        appAudioState = .monitoring
    }

    /// 外部功能（如视频预览）在**仍处于监测意图**下恢复采集管道时调用。
    func restoreMonitoringPipelineIfNeeded() {
        guard appAudioState == .monitoring, engine.isMonitoring else { return }
        engine.restoreMonitoringAfterExternalSession()
    }

    // MARK: - Private

    /// 重新配置为测量模式：线性 PCM、关闭系统语音处理，保证 dB 计算准确。
    private func reconfigureMeasurementSession() throws {
        try BackgroundAudioSession.activateForMeasurement(
            backgroundEnabled: engine.backgroundMonitoringEnabled,
            skipSessionActivation: false
        )
    }
}
