import WidgetKit
import SwiftUI

/// Phase-2 complication entry point. Register in a Widget Extension target when enabling complications.
struct NoiseComplicationEntry: TimelineEntry {
    let date: Date
    let decibel: Float
    let isMonitoring: Bool
}

struct NoiseComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoiseComplicationEntry {
        NoiseComplicationEntry(date: .now, decibel: 42, isMonitoring: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NoiseComplicationEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoiseComplicationEntry>) -> Void) {
        let entry = currentEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30)))
        completion(timeline)
    }

    private func currentEntry() -> NoiseComplicationEntry {
        if let snapshot = WatchSnapshotStore.load() {
            return NoiseComplicationEntry(
                date: snapshot.updatedAt,
                decibel: snapshot.currentDB,
                isMonitoring: snapshot.isMonitoring
            )
        }
        return NoiseComplicationEntry(date: .now, decibel: 0, isMonitoring: false)
    }
}

struct NoiseComplicationView: View {
    let entry: NoiseComplicationEntry

    var body: some View {
        VStack(spacing: 0) {
            Text(String(format: "%.0f", entry.decibel))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(entry.isMonitoring ? "dB" : "—")
                .font(.caption2)
        }
    }
}
