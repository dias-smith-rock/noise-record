import SwiftUI
import UIKit

struct ModeSwitchView: View {
    @Binding var mode: AcousticMeasurementMode
    var isMonitoring: Bool = false
    var onModeChanged: ((AcousticMeasurementMode) -> Void)?

    @State private var showModeInfoSheet = false

    private var theme: ModeVisualTheme { .theme(for: mode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            modePicker
        }
        .padding(12)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showModeInfoSheet) {
            MeasurementModesInfoSheet()
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.modeSwitchTitle)
                    .font(.subheadline.bold())
                Text(mode.userFacingTitle)
                    .font(.caption2)
                    .foregroundStyle(theme.accent)
            }

            Spacer(minLength: 8)

            Button {
                showModeInfoSheet = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.modeSwitchAccessibility)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 3) {
            ForEach(AcousticMeasurementMode.allCases) { item in
                modeSegment(for: item)
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func modeSegment(for item: AcousticMeasurementMode) -> some View {
        let isSelected = mode == item
        let itemTheme = ModeVisualTheme.theme(for: item)

        return Button {
            guard mode != item else { return }
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()

            if item == .standard {
                AppTelemetry.logProductEvent(
                    "mode_standard_selected",
                    parameters: [
                        "is_monitoring": isMonitoring ? "true" : "false",
                    ]
                )
            }

            ModeSwitchPerformance.beginSession(from: mode, to: item, isMonitoring: isMonitoring)

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                mode = item
            }
            ModeSwitchPerformance.mark(.uiModeApplied)
            onModeChanged?(item)
        } label: {
            VStack(spacing: 2) {
                Text(item.segmentLabel)
                    .font(.caption.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(item.technicalBadge)
                    .font(.caption2)
                    .opacity(0.88)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? itemTheme.accent : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// Bridges `NoiseMonitorEngine.isHighSensitivityMode` to `ModeSwitchView`.
struct EngineModeSwitchView: View {
    @Bindable var engine: NoiseMonitorEngine

    private var modeBinding: Binding<AcousticMeasurementMode> {
        Binding(
            get: { AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode) },
            set: { newMode in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    engine.isHighSensitivityMode = newMode.isHighSensitivity
                }
            }
        )
    }

    var body: some View {
        ModeSwitchView(
            mode: modeBinding,
            isMonitoring: engine.isMonitoring
        )
    }
}
