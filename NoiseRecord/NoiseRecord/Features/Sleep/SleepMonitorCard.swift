import SwiftUI

struct SleepMonitorHeaderMenu: View, Equatable {
    let isSleepMonitoring: Bool
    let isGeneralMonitoringActive: Bool
    let sleepMonitoringStartedAt: Date?
    let latestCompletedSessionID: UUID?
    let measurementMode: AcousticMeasurementMode
    let onViewLatestReport: () -> Void
    let onViewHistory: () -> Void
    let onStartSleepMonitoring: () async -> Void

    @State private var isStarting = false
    @State private var pendingNavigation: PendingNavigation?

    private enum PendingNavigation: Equatable {
        case latestReport
        case history
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isSleepMonitoring == rhs.isSleepMonitoring
            && lhs.isGeneralMonitoringActive == rhs.isGeneralMonitoringActive
            && lhs.sleepMonitoringStartedAt == rhs.sleepMonitoringStartedAt
            && lhs.latestCompletedSessionID == rhs.latestCompletedSessionID
            && lhs.measurementMode == rhs.measurementMode
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        HStack(spacing: 8) {
            if isSleepMonitoring {
                Menu {
                    sleepHistoryAndReportMenuItems(includeStart: false)
                } label: {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        sleepCapsule(title: elapsedText, systemImage: "moon.stars.fill", prominent: true)
                    }
                }
            } else if isGeneralMonitoringActive {
                Menu {
                    sleepHistoryAndReportMenuItems(includeStart: false)
                } label: {
                    moonIconLabel
                }
            } else {
                ProTabHeaderIconButton(systemImage: "moon.zzz.fill", theme: theme) {
                    sleepHistoryAndReportMenuItems(includeStart: true)
                }
                .disabled(isStarting)
            }
        }
        .onChange(of: pendingNavigation) { _, action in
            guard let action else { return }
            pendingNavigation = nil
            Task { @MainActor in
                switch action {
                case .latestReport:
                    onViewLatestReport()
                case .history:
                    onViewHistory()
                }
            }
        }
    }

    @ViewBuilder
    private func sleepHistoryAndReportMenuItems(includeStart: Bool) -> some View {
        if includeStart {
            Button {
                Task { await startSleepMonitoring() }
            } label: {
                sleepMenuLabel(L10n.sleepMenuStart, systemImage: "bed.double.fill")
            }
            .disabled(isStarting)
        }

        if latestCompletedSessionID == nil {
            Button {} label: {
                sleepMenuLabel(L10n.sleepMenuNoReport, systemImage: "doc.text.fill")
            }
            .disabled(true)
        } else {
            Button {
                pendingNavigation = .latestReport
            } label: {
                sleepMenuLabel(L10n.sleepMenuLatestReport, systemImage: "doc.text.fill")
            }
        }

        Button {
            pendingNavigation = .history
        } label: {
            sleepMenuLabel(L10n.sleepMenuHistory, systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    private func sleepMenuLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
        }
    }

    private var moonIconLabel: some View {
        Image(systemName: "moon.zzz.fill")
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.accent)
            .frame(width: 36, height: 36)
            .background(theme.badgeBackground)
            .clipShape(Circle())
            .contentShape(Circle())
    }

    private var elapsedText: String {
        guard let sleepMonitoringStartedAt else { return "—" }
        return DurationFormatting.hms(from: Date().timeIntervalSince(sleepMonitoringStartedAt))
    }

    private func sleepCapsule(title: String, systemImage: String, prominent: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(prominent ? .white : theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(prominent ? theme.accent : theme.badgeBackground)
        .clipShape(Capsule())
    }

    private func startSleepMonitoring() async {
        isStarting = true
        defer { isStarting = false }
        await onStartSleepMonitoring()
    }
}
