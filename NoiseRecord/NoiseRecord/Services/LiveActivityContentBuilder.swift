import Foundation

enum LiveActivityContentBuilder {
    static func noiseSceneDescription(db: Float, highSensitivity: Bool) -> String {
        let level = NoiseRiskLevel.from(db: db, highSensitivity: highSensitivity)
        switch level {
        case .quiet: return L10n.liveActivitySceneWhisper
        case .moderate: return L10n.liveActivitySceneConversation
        case .loud: return L10n.liveActivitySceneTraffic
        case .dangerous: return L10n.liveActivitySceneDrill
        }
    }

    static func statusMessage(
        isHighSensitivity: Bool,
        recordingState: RecordingState,
        voiceActivatedEnabled: Bool
    ) -> String {
        switch recordingState {
        case .recording:
            return L10n.liveActivityStatusVoiceRecording
        case .coolingDown:
            return L10n.recordingTailDelay
        case .idle:
            if voiceActivatedEnabled {
                return L10n.liveActivityStatusVoiceStandby
            }
            return isHighSensitivity
                ? L10n.liveActivityStatusMonitoringHighSensitivity
                : L10n.liveActivityStatusMonitoringStandard
        }
    }

    static func weightingLabel(isHighSensitivity: Bool, weightingType: WeightingType) -> String {
        if isHighSensitivity {
            return AcousticMeasurementMode.highSensitivity.localizedTechnicalBadge
        }
        switch weightingType {
        case .a: return "dBA"
        case .c: return "dBC"
        case .z: return "dBZ"
        }
    }

    static func measurementModeName(isHighSensitivity: Bool) -> String {
        AcousticMeasurementMode(isHighSensitivity: isHighSensitivity).localizedUserFacingTitle
    }

    static func initialWeightingBadge(isHighSensitivity: Bool) -> String {
        AcousticMeasurementMode(isHighSensitivity: isHighSensitivity).localizedTechnicalBadge
    }

    static func waveformLevels(from history: [Float], currentDB: Float) -> [Float] {
        LiveActivityStyle.normalizedWaveformLevels(history, fallbackDB: currentDB)
    }
}
