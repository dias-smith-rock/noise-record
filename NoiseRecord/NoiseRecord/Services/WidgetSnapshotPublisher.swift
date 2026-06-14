import Foundation
import WidgetKit

@MainActor
enum WidgetSnapshotPublisher {
    private static var lastPublishedAt: Date?
    private static let throttleInterval: TimeInterval = 1

    static func publish(
        currentDB: Float,
        maxDB: Float,
        minDB: Float,
        averageDB: Float,
        leq: Float,
        weightingBadge: String,
        isHighSensitivity: Bool,
        isMonitoring: Bool,
        recordingState: RecordingState,
        history: [Float],
        force: Bool = false
    ) {
        let now = Date()
        if !force,
           let lastPublishedAt,
           now.timeIntervalSince(lastPublishedAt) < throttleInterval {
            return
        }
        lastPublishedAt = now

        let trimmedHistory = Array(history.suffix(WidgetMonitoringSnapshot.historyLimit))
        let snapshot = WidgetMonitoringSnapshot(
            currentDB: currentDB,
            maxDB: maxDB,
            minDB: minDB,
            averageDB: averageDB,
            leq: leq,
            weightingBadge: weightingBadge,
            isHighSensitivity: isHighSensitivity,
            isMonitoring: isMonitoring,
            recordingState: mapRecordingState(recordingState),
            history: trimmedHistory,
            updatedAt: now
        )
        WidgetSnapshotStore.save(snapshot)
        reloadWidgetTimelines()
    }

    static func publishStoppedState(from engine: NoiseMonitorEngine) {
        let existing = WidgetSnapshotStore.load()
        let snapshot = WidgetMonitoringSnapshot(
            currentDB: existing?.currentDB ?? engine.currentDB,
            maxDB: existing?.maxDB ?? engine.maxDB,
            minDB: existing?.minDB ?? engine.minDB,
            averageDB: existing?.averageDB ?? engine.averageDB,
            leq: existing?.leq ?? engine.leq,
            weightingBadge: existing?.weightingBadge ?? weightingBadge(for: engine),
            isHighSensitivity: engine.isHighSensitivityMode,
            isMonitoring: false,
            recordingState: .idle,
            history: existing?.history ?? Array(engine.history.suffix(WidgetMonitoringSnapshot.historyLimit)),
            updatedAt: existing?.updatedAt ?? .now
        )
        lastPublishedAt = Date()
        WidgetSnapshotStore.save(snapshot)
        reloadWidgetTimelines()
    }

    static func publishFromEngine(_ engine: NoiseMonitorEngine, force: Bool = false) {
        publish(
            currentDB: engine.currentDB,
            maxDB: engine.maxDB,
            minDB: engine.minDB,
            averageDB: engine.averageDB,
            leq: engine.leq,
            weightingBadge: weightingBadge(for: engine),
            isHighSensitivity: engine.isHighSensitivityMode,
            isMonitoring: engine.isMonitoring,
            recordingState: engine.recordingState,
            history: engine.history,
            force: force
        )
    }

    private static func weightingBadge(for engine: NoiseMonitorEngine) -> String {
        engine.effectiveWeighting.rawValue
    }

    private static func mapRecordingState(_ state: RecordingState) -> WidgetRecordingState {
        switch state {
        case .idle: .idle
        case .recording: .recording
        case .coolingDown: .coolingDown
        }
    }

    private static func reloadWidgetTimelines() {
        for kind in WidgetKind.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
