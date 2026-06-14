import WidgetKit
import SwiftUI

struct MonitoringSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonitoringEntry {
        MonitoringEntry(date: .now, snapshot: sampleSnapshot(isMonitoring: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (MonitoringEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? sampleSnapshot(isMonitoring: false)
        completion(MonitoringEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonitoringEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        let entry = MonitoringEntry(date: now, snapshot: snapshot)
        let refreshDate: Date
        if snapshot.isEffectivelyMonitoring(at: now) {
            refreshDate = now.addingTimeInterval(5)
        } else if snapshot.hasData, snapshot.isRecentlyActive(at: now) {
            refreshDate = now.addingTimeInterval(15)
        } else if snapshot.hasData {
            refreshDate = now.addingTimeInterval(900)
        } else {
            refreshDate = now.addingTimeInterval(3600)
        }
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func sampleSnapshot(isMonitoring: Bool) -> WidgetMonitoringSnapshot {
        WidgetMonitoringSnapshot(
            currentDB: 52.4,
            maxDB: 68.2,
            minDB: 41.0,
            averageDB: 49.8,
            leq: 50.1,
            weightingBadge: "A",
            isHighSensitivity: false,
            isMonitoring: isMonitoring,
            recordingState: .idle,
            history: [40, 42, 45, 48, 52, 50, 47],
            updatedAt: .now
        )
    }
}

struct MonitoringEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMonitoringSnapshot
}
