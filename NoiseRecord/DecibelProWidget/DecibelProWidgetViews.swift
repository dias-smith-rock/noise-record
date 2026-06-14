import AppIntents
import SwiftUI
import WidgetKit

struct LiveMeterWidgetView: View {
    let entry: MonitoringEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetMonitoringSnapshot { entry.snapshot }
    private var accent: Color { WidgetTheme.accent(highSensitivity: snapshot.isHighSensitivity) }
    private var risk: WidgetRiskLevel {
        .from(db: snapshot.currentDB, highSensitivity: snapshot.isHighSensitivity)
    }

    private var isEffectivelyMonitoring: Bool {
        snapshot.isEffectivelyMonitoring()
    }

    var body: some View {
        Group {
            if snapshot.hasData || isEffectivelyMonitoring {
                content
            } else {
                placeholder
            }
        }
        .widgetURL(WidgetDeepLink.monitorStartURL)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            header
            HStack(alignment: .center, spacing: 10) {
                gauge
                if family != .systemSmall {
                    sideStats
                }
            }
            footer
        }
        .widgetContentPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack {
            Text(WidgetStrings.liveTitle)
                .font(.caption.bold())
                .foregroundStyle(accent)
            Spacer()
            Text(snapshot.weightingBadge)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(accent.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private var gauge: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.15), lineWidth: family == .systemSmall ? 10 : 12)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(snapshot.currentDB, 0), 120) / 120))
                .stroke(
                    AngularGradient(colors: WidgetTheme.gaugeGradient(highSensitivity: snapshot.isHighSensitivity) + [accent.opacity(0.4)], center: .center),
                    style: StrokeStyle(lineWidth: family == .systemSmall ? 10 : 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(String(format: "%.1f", snapshot.currentDB))
                    .font(.system(size: family == .systemSmall ? 28 : 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("dB")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: family == .systemSmall ? 76 : 84, height: family == .systemSmall ? 76 : 84)
    }

    private var sideStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            statRow(title: WidgetStrings.statMax, value: snapshot.maxDB)
            statRow(title: WidgetStrings.statMin, value: snapshot.minDB)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isEffectivelyMonitoring ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(isEffectivelyMonitoring ? WidgetStrings.statusMonitoring : WidgetStrings.statusIdle)
                    .font(.caption2)
                    .foregroundStyle(isEffectivelyMonitoring ? .primary : .secondary)
            }
            if !isEffectivelyMonitoring, snapshot.hasData {
                Text(WidgetRelativeTimeFormatter.string(from: snapshot.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(accent)
            Text(WidgetStrings.placeholderStart)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .widgetContentPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statRow(title: String, value: Float) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f", value))
                .font(.caption.bold())
                .monospacedDigit()
        }
    }
}

struct LiveMeterWidget: Widget {
    let kind = WidgetKind.liveMeter

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonitoringSnapshotProvider()) { entry in
            LiveMeterWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ContainerRelativeShape()
                        .fill(Color(.systemBackground))
                }
        }
        .configurationDisplayName(LocalizedStringResource("widget.live.title"))
        .description(LocalizedStringResource("widget.live.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SessionStatsWidgetView: View {
    let entry: MonitoringEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetMonitoringSnapshot { entry.snapshot }
    private var accent: Color { WidgetTheme.accent(highSensitivity: snapshot.isHighSensitivity) }
    private var isEffectivelyMonitoring: Bool { snapshot.isEffectivelyMonitoring() }

    var body: some View {
        Group {
            if snapshot.hasData || isEffectivelyMonitoring {
                content
            } else {
                LiveMeterWidgetView(entry: entry)
            }
        }
        .widgetURL(WidgetDeepLink.monitorStartURL)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(WidgetStrings.statsTitle)
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                Spacer()
                Text(String(format: "%.1f dB", snapshot.currentDB))
                    .font(.caption.bold())
                    .monospacedDigit()
            }

            statsGrid

            if family == .systemLarge, !snapshot.history.isEmpty {
                miniWaveform
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(isEffectivelyMonitoring ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(isEffectivelyMonitoring ? WidgetStrings.statusMonitoring : WidgetStrings.statusIdle)
                    .font(.caption2)
                if !isEffectivelyMonitoring, snapshot.hasData {
                    Spacer()
                    Text(WidgetRelativeTimeFormatter.string(from: snapshot.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .widgetContentPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            statTile(title: WidgetStrings.statMax, value: snapshot.maxDB)
            statTile(title: WidgetStrings.statMin, value: snapshot.minDB)
            statTile(title: WidgetStrings.statAvg, value: snapshot.averageDB)
            statTile(title: WidgetStrings.statLeq, value: snapshot.leq)
        }
    }

    private var miniWaveform: some View {
        GeometryReader { proxy in
            let values = snapshot.history
            let maxValue = max(values.max() ?? 1, 1)
            let minValue = values.min() ?? 0
            let span = max(maxValue - minValue, 1)
            Path { path in
                guard values.count > 1 else { return }
                let stepX = proxy.size.width / CGFloat(values.count - 1)
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalized = (value - minValue) / span
                    let y = proxy.size.height * (1 - CGFloat(normalized))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 56)
    }

    private func statTile(title: String, value: Float) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.headline.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SessionStatsWidget: Widget {
    let kind = WidgetKind.sessionStats

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonitoringSnapshotProvider()) { entry in
            SessionStatsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ContainerRelativeShape()
                        .fill(Color(.systemBackground))
                }
        }
        .configurationDisplayName(LocalizedStringResource("widget.stats.title"))
        .description(LocalizedStringResource("widget.stats.description"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct MonitoringControlWidgetView: View {
    let entry: MonitoringEntry

    private var snapshot: WidgetMonitoringSnapshot { entry.snapshot }
    private var accent: Color { WidgetTheme.accent(highSensitivity: snapshot.isHighSensitivity) }
    private var isEffectivelyMonitoring: Bool { snapshot.isEffectivelyMonitoring() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(WidgetStrings.liveTitle)
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                Spacer()
                Circle()
                    .fill(isEffectivelyMonitoring ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
            }

            Text(isEffectivelyMonitoring ? WidgetStrings.statusMonitoring : WidgetStrings.statusIdle)
                .font(.headline)

            if snapshot.hasData {
                Text(String(format: "%.1f dB", snapshot.currentDB))
                    .font(.title2.bold())
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                Button(intent: StartMonitoringIntent()) {
                    Label(WidgetStrings.intentStart, systemImage: "play.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(isEffectivelyMonitoring)

                Button(intent: StopMonitoringIntent()) {
                    Label(WidgetStrings.intentStop, systemImage: "stop.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isEffectivelyMonitoring)
            }
        }
        .widgetContentPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeepLink.monitorURL)
    }
}

struct MonitoringControlWidget: Widget {
    let kind = WidgetKind.monitoringControl

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonitoringSnapshotProvider()) { entry in
            MonitoringControlWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ContainerRelativeShape()
                        .fill(Color(.systemBackground))
                }
        }
        .configurationDisplayName(LocalizedStringResource("widget.control.title"))
        .description(LocalizedStringResource("widget.control.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
