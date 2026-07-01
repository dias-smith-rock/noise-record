import ActivityKit
import Foundation
import os

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let logger = Logger(subsystem: "com.goodcraft.NoiseRecord", category: "LiveActivity")
    private var activity: Activity<NoiseMonitorAttributes>?
    private var updateTask: Task<Void, Never>?
    private var pendingState: NoiseMonitorAttributes.ContentState?
    private var lastDeliveredAt = Date.distantPast
    private var lastDeliveredDecibel: Float = -999

    private let minUpdateInterval: TimeInterval = 0.25
    private let minDecibelDelta: Float = 0.2

    var isActive: Bool { activity != nil }

    private init() {}

    func startLiveActivity(
        measurementModeName: String,
        weightingBadge: String,
        isHighSensitivityMode: Bool
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities disabled by system or user.")
            return
        }

        await endLiveActivity()

        let attributes = NoiseMonitorAttributes(
            measurementModeName: measurementModeName,
            weightingBadge: weightingBadge,
            isHighSensitivityMode: isHighSensitivityMode,
            sessionStartedAt: .now
        )
        let initialState = NoiseMonitorAttributes.ContentState(
            currentDecibel: 0,
            noiseLevelDescription: L10n.liveActivitySceneWhisper,
            statusMessage: L10n.liveActivityStatusMonitoringStandard,
            weightingLabel: weightingBadge,
            waveformLevels: [0.15, 0.15, 0.15, 0.15, 0.15]
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            pendingState = initialState
            lastDeliveredAt = .now
            lastDeliveredDecibel = 0
            logger.info("Live Activity started.")
            AppTelemetry.logProductEvent(
                "live_activity_started",
                parameters: [
                    "mode": isHighSensitivityMode ? "high_sensitivity" : "standard",
                ]
            )
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updateLiveActivity(
        db: Float,
        description: String,
        status: String,
        weightingLabel: String,
        waveformLevels: [Float]
    ) {
        guard activity != nil else { return }
        pendingState = NoiseMonitorAttributes.ContentState(
            currentDecibel: db,
            noiseLevelDescription: description,
            statusMessage: status,
            weightingLabel: weightingLabel,
            waveformLevels: waveformLevels
        )
        scheduleUpdate(force: false)
    }

    func pushAudioBufferUpdate(
        currentDB: Float,
        isHighSensitivity: Bool,
        weightingType: WeightingType,
        recordingState: RecordingState,
        historyTail: [Float]
    ) {
        Task { @MainActor in
            guard self.isActive else { return }
            let description = LiveActivityContentBuilder.noiseSceneDescription(
                db: currentDB,
                highSensitivity: isHighSensitivity
            )
            let status = LiveActivityContentBuilder.statusMessage(
                isHighSensitivity: isHighSensitivity,
                recordingState: recordingState
            )
            let weighting = LiveActivityContentBuilder.weightingLabel(
                isHighSensitivity: isHighSensitivity,
                weightingType: weightingType
            )
            let waveform = LiveActivityContentBuilder.waveformLevels(
                from: historyTail,
                currentDB: currentDB
            )
            self.updateLiveActivity(
                db: currentDB,
                description: description,
                status: status,
                weightingLabel: weighting,
                waveformLevels: waveform
            )
        }
    }

    func endLiveActivity() async {
        updateTask?.cancel()
        updateTask = nil
        pendingState = nil

        guard let activity else { return }
        self.activity = nil

        let finalState = NoiseMonitorAttributes.ContentState(
            currentDecibel: 0,
            noiseLevelDescription: L10n.liveActivitySceneWhisper,
            statusMessage: L10n.liveActivityStatusEnded,
            weightingLabel: activity.attributes.weightingBadge,
            waveformLevels: [0.12, 0.12, 0.12, 0.12, 0.12]
        )
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        logger.info("Live Activity ended.")
    }

    private func scheduleUpdate(force: Bool) {
        guard let activity, let state = pendingState else { return }

        let now = Date()
        if !force {
            let elapsed = now.timeIntervalSince(lastDeliveredAt)
            let delta = abs(state.currentDecibel - lastDeliveredDecibel)
            if elapsed < minUpdateInterval, delta < minDecibelDelta {
                return
            }
        }

        updateTask?.cancel()
        updateTask = Task { @MainActor in
            let content = ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(1),
                relevanceScore: 100
            )
            await activity.update(content)
            lastDeliveredAt = Date()
            lastDeliveredDecibel = state.currentDecibel
        }
    }
}
