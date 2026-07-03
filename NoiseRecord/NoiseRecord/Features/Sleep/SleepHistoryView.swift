import Charts
import SwiftData
import SwiftUI

struct SleepHistoryView: View {
    var measurementMode: AcousticMeasurementMode = .standard

    @Environment(\.modelContext) private var modelContext
    @Bindable private var appearance = AppAppearanceSettings.shared
    @State private var sessions: [SleepNoiseSession] = []

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        let _ = appearance.accentRefreshID

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProSectionHeader(
                    title: L10n.sleepHistoryTitle,
                    subtitle: L10n.sleepHistorySubtitle,
                    theme: theme
                )

                if sessions.isEmpty {
                    Text(L10n.sleepHistoryEmpty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 24)
                } else {
                    summarySection
                    chartSection
                    sessionListSection
                    Text(L10n.sleepReportDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.sleepHistoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
        .observesAppLanguage()
        .onAppear { reload() }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = historySummary {
            ProCard(theme: theme) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.sleepHistorySummaryAvgLeq(String(format: "%.0f", summary.averageLeq)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                    Text(
                        L10n.sleepHistorySummaryBestNight(
                            shortChartDate(summary.bestSession.startedAt),
                            summary.bestSession.silenceGrade.rawValue
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(
                        L10n.sleepHistorySummaryWorstNight(
                            shortChartDate(summary.worstSession.startedAt),
                            summary.worstSession.silenceGrade.rawValue
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(L10n.sleepHistorySummaryTotalAnomalies(summary.totalAnomalies))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        if #available(iOS 16.0, *) {
            ProCard(theme: theme) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.sleepHistoryTrendTitle)
                        .font(.headline)

                    Chart {
                        ForEach(sessions.reversed(), id: \.id) { session in
                            LineMark(
                                x: .value("Date", session.startedAt),
                                y: .value("Leq", session.overallLeq)
                            )
                            .foregroundStyle(by: .value("Series", "Leq"))
                            PointMark(
                                x: .value("Date", session.startedAt),
                                y: .value("Leq", session.overallLeq)
                            )
                            .foregroundStyle(by: .value("Series", "Leq"))

                            LineMark(
                                x: .value("Date", session.startedAt),
                                y: .value("Floor", session.noiseFloorDB)
                            )
                            .foregroundStyle(by: .value("Series", "Floor"))
                            PointMark(
                                x: .value("Date", session.startedAt),
                                y: .value("Floor", session.noiseFloorDB)
                            )
                            .foregroundStyle(by: .value("Series", "Floor"))
                        }
                    }
                    .chartForegroundStyleScale([
                        "Leq": theme.accent,
                        "Floor": Color.secondary,
                    ])
                    .chartLegend(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(shortChartDate(date))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 180)

                    HStack(spacing: 16) {
                        legendItem(color: theme.accent, title: "Leq")
                        legendItem(color: .secondary, title: L10n.sleepHistoryChartFloorLegend)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sessionListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(sessions, id: \.id) { session in
                NavigationLink {
                    SleepReportDetailView(sessionID: session.id)
                } label: {
                    historyCard(session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func historyCard(_ session: SleepNoiseSession) -> some View {
        let sessionTheme = ModeVisualTheme.theme(
            for: session.isHighSensitivitySession ? .highSensitivity : .standard
        )

        ProCard(theme: sessionTheme) {
            HStack(alignment: .top, spacing: 12) {
                Text(session.silenceGrade.rawValue)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(sessionTheme.accent)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(formattedSessionDate(session.startedAt))
                            .font(.subheadline.weight(.semibold))
                        if !session.isReportRead {
                            Circle()
                                .fill(sessionTheme.accent)
                                .frame(width: 8, height: 8)
                        }
                        Spacer()
                    }

                    Text(session.silenceGrade.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(
                        L10n.sleepHistoryRowMetrics(
                            overall: String(format: "%.0f", session.overallLeq),
                            floor: String(format: "%.0f", session.noiseFloorDB)
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(anomalySummary(for: session))
                        if let durationText = monitoringDurationText(for: session) {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(durationText)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    if session.isHighSensitivitySession {
                        Text(AcousticMeasurementMode.highSensitivity.technicalBadge)
                            .font(.caption2.bold())
                            .foregroundStyle(sessionTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(sessionTheme.badgeBackground)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
    }

    private func anomalySummary(for session: SleepNoiseSession) -> String {
        if session.anomalyCount == 0 {
            return L10n.sleepHistoryQuietNight
        }
        return L10n.sleepHistoryAnomaliesCount(session.anomalyCount)
    }

    private func monitoringDurationText(for session: SleepNoiseSession) -> String? {
        guard let endedAt = session.endedAt else { return nil }
        let duration = endedAt.timeIntervalSince(session.startedAt)
        guard duration > 0 else { return nil }
        return L10n.sleepHistoryMonitoringDuration(
            DurationFormatting.compactHoursMinutes(from: duration)
        )
    }

    private var historySummary: HistorySummary? {
        guard !sessions.isEmpty else { return nil }
        let averageLeq = sessions.map(\.overallLeq).reduce(0, +) / Float(sessions.count)
        guard let bestSession = sessions.min(by: { $0.overallLeq < $1.overallLeq }),
              let worstSession = sessions.max(by: { $0.overallLeq < $1.overallLeq }) else {
            return nil
        }
        let totalAnomalies = sessions.map(\.anomalyCount).reduce(0, +)
        return HistorySummary(
            averageLeq: averageLeq,
            bestSession: bestSession,
            worstSession: worstSession,
            totalAnomalies: totalAnomalies
        )
    }

    private func reload() {
        sessions = SleepMeasurementPersistence.recentSessions(limit: 7, in: modelContext)
    }

    private func formattedSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.resolvedLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }

    private func shortChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.resolvedLocale
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }
}

private struct HistorySummary {
    let averageLeq: Float
    let bestSession: SleepNoiseSession
    let worstSession: SleepNoiseSession
    let totalAnomalies: Int
}

private struct SleepReportDetailView: View {
    let sessionID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SleepReportView(
            sessionID: sessionID,
            showsHistoryButton: false,
            onDismiss: { dismiss() }
        )
    }
}
