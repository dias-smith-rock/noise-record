import SwiftUI
import UIKit

struct ModeSwitchView: View {
    @Binding var mode: AcousticMeasurementMode
    var showsInlineHint: Bool = true
    var onModeChanged: ((AcousticMeasurementMode) -> Void)?

    @State private var showExplanation = false
    @State private var explanationMode: AcousticMeasurementMode = .standard

    private var theme: ModeVisualTheme { .theme(for: mode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            modePicker

            if showsInlineHint {
                inlineHintCard
            }
        }
        .padding(14)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.28), value: mode)
        .sheet(isPresented: $showExplanation) {
            ModeExplanationSheet(mode: explanationMode)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.modeSwitchTitle)
                    .font(.subheadline.bold())
                Text(mode.userFacingTitle)
                    .font(.caption)
                    .foregroundStyle(theme.accent)
            }

            Spacer()

            Button {
                explanationMode = mode
                showExplanation = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel(L10n.modeSwitchAccessibility)
            }
            .buttonStyle(.plain)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(AcousticMeasurementMode.allCases) { item in
                modeSegment(for: item)
            }
        }
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func modeSegment(for item: AcousticMeasurementMode) -> some View {
        let isSelected = mode == item
        let itemTheme = ModeVisualTheme.theme(for: item)

        return Button {
            guard mode != item else { return }
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()

            withAnimation(.easeInOut(duration: 0.25)) {
                mode = item
            }
            onModeChanged?(item)
        } label: {
            VStack(spacing: 4) {
                Text(item.segmentLabel)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                Text(item.technicalBadge)
                    .font(.caption2)
                    .opacity(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? itemTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    private var inlineHintCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mode.isHighSensitivity ? "bolt.horizontal.circle.fill" : "checkmark.shield.fill")
                .foregroundStyle(theme.accent)
                .font(.body)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.comparisonHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(L10n.modeSwitchLearnMore) {
                    explanationMode = mode
                    showExplanation = true
                }
                .font(.caption.bold())
                .foregroundStyle(theme.accent)
            }
        }
    }
}

/// Bridges `NoiseMonitorEngine.isHighSensitivityMode` to `ModeSwitchView`.
struct EngineModeSwitchView: View {
    @Bindable var engine: NoiseMonitorEngine
    var showsInlineHint: Bool = true

    private var modeBinding: Binding<AcousticMeasurementMode> {
        Binding(
            get: { AcousticMeasurementMode(isHighSensitivity: engine.isHighSensitivityMode) },
            set: { newMode in
                engine.isHighSensitivityMode = newMode.isHighSensitivity
            }
        )
    }

    var body: some View {
        ModeSwitchView(mode: modeBinding, showsInlineHint: showsInlineHint)
    }
}
