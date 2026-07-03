import Charts
import SwiftData
import SwiftUI

struct SleepHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sessions: [SleepNoiseSession] = []

    private var theme: ModeVisualTheme {
        .theme(for: .standard)
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                Text(L10n.sleepHistoryEmpty)
                    .foregroundStyle(.secondary)
            } else {
                chartSection
                ForEach(sessions, id: \.id) { session in
                    NavigationLink {
                        SleepReportDetailView(sessionID: session.id)
                    } label: {
                        historyRow(session)
                    }
                }
            }
        }
        .navigationTitle(L10n.sleepHistoryTitle)
        .onAppear { reload() }
    }

    @ViewBuilder
    private var chartSection: some View {
        if #available(iOS 16.0, *) {
            Section(L10n.sleepHistoryTrendTitle) {
                Chart(sessions.reversed(), id: \.id) { session in
                    LineMark(
                        x: .value("Date", session.startedAt),
                        y: .value("Leq", session.overallLeq)
                    )
                    .foregroundStyle(theme.accent)
                    PointMark(
                        x: .value("Date", session.startedAt),
                        y: .value("Leq", session.overallLeq)
                    )
                    .foregroundStyle(theme.accent)
                }
                .frame(height: 180)
            }
        }
    }

    private func historyRow(_ session: SleepNoiseSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate(session.startedAt))
                .font(.subheadline.weight(.semibold))
            Text(
                L10n.sleepHistoryRowSummary(
                    leq: String(format: "%.0f", session.overallLeq),
                    floor: String(format: "%.0f", session.noiseFloorDB),
                    anomalies: session.anomalyCount
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func reload() {
        sessions = SleepMeasurementPersistence.recentSessions(limit: 7, in: modelContext)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.resolvedLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct SleepReportDetailView: View {
    let sessionID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SleepReportView(sessionID: sessionID, onDismiss: { dismiss() })
    }
}
