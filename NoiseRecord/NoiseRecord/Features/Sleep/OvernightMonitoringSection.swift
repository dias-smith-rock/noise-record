import SwiftUI

struct OvernightMonitoringSection: View {
    let theme: ModeVisualTheme
    let isSleepMonitoring: Bool
    let canStartOvernight: Bool
    let sleepMonitoringStartedAt: Date?
    let hasLatestReport: Bool
    let onStart: () async -> Void
    let onOpenReport: () -> Void
    let onOpenHistory: () -> Void

    @State private var isStarting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.dashboardOvernightMonitoringTitle)
                .font(.headline)

            Text(L10n.sleepMonitorSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    if isSleepMonitoring, sleepMonitoringStartedAt != nil {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            monitoringStatusRow(elapsedText: elapsedText ?? "—")
                        }
                        rowDivider
                    } else if canStartOvernight {
                        actionRow(
                            title: L10n.sleepMenuStart,
                            description: L10n.dashboardOvernightMonitoringStartBody,
                            systemImage: "bed.double.fill",
                            isEnabled: !isStarting
                        ) {
                            await handleStartTapped()
                        }
                        rowDivider
                    }

                    actionRow(
                        title: L10n.sleepMenuLatestReport,
                        description: hasLatestReport
                            ? L10n.dashboardOvernightMonitoringReportBody
                            : L10n.sleepMenuNoReport,
                        systemImage: "doc.text.fill",
                        isEnabled: hasLatestReport
                    ) {
                        logPanelTap(action: "report")
                        onOpenReport()
                    }
                    rowDivider

                    actionRow(
                        title: L10n.sleepMenuHistory,
                        description: L10n.dashboardOvernightMonitoringHistoryBody,
                        systemImage: "chart.line.uptrend.xyaxis",
                        isEnabled: true
                    ) {
                        logPanelTap(action: "history")
                        onOpenHistory()
                    }
                }
            }
        }
    }

    private var elapsedText: String? {
        guard let sleepMonitoringStartedAt else { return nil }
        return DurationFormatting.hms(from: Date().timeIntervalSince(sleepMonitoringStartedAt))
    }

    private func monitoringStatusRow(elapsedText: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.dashboardOvernightMonitoringActiveTitle)
                    .font(.subheadline.weight(.semibold))
                Text(L10n.dashboardOvernightMonitoringActiveBody(elapsedText))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func actionRow(
        title: String,
        description: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionRowContent(
                title: title,
                description: description,
                systemImage: systemImage,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func actionRow(
        title: String,
        description: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            actionRowContent(
                title: title,
                description: description,
                systemImage: systemImage,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func actionRowContent(
        title: String,
        description: String,
        systemImage: String,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Divider()
            .overlay(theme.surfaceBorder.opacity(0.65))
    }

    private func handleStartTapped() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        logPanelTap(action: "start")
        await onStart()
    }

    private func logPanelTap(action: String) {
        AppTelemetry.logProductEvent(
            "sleep_overnight_panel_tap",
            parameters: ["action": action]
        )
    }
}
