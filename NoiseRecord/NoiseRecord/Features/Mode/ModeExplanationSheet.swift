import SwiftUI

struct ModeExplanationSheet: View {
    let mode: AcousticMeasurementMode
    @Environment(\.dismiss) private var dismiss

    private var theme: ModeVisualTheme { .theme(for: mode) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modeHero

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.modeGuideWhatDoesItDo)
                            .font(.headline)
                        Text(mode.coreDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.modeGuideDetails)
                            .font(.headline)
                        Text(mode.tooltipCopy)
                            .font(.body)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(theme.cardTint)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.modeGuideWhyDifferent, systemImage: "questionmark.circle")
                            .font(.subheadline.bold())
                        Text(mode.comparisonHint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    modeComparisonCard
                }
                .padding()
            }
            .navigationTitle(L10n.modeGuideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.gotIt) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var modeHero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: mode.isHighSensitivity ? "waveform.path.ecg" : "ear.fill")
                .font(.title)
                .foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .background(theme.badgeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(mode.userFacingTitle)
                    .font(.title3.bold())
                Text(mode.technicalBadge)
                    .font(.caption.bold())
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.badgeBackground)
                    .clipShape(Capsule())
            }
        }
    }

    private var modeComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.modeGuideWhichMode)
                .font(.headline)

            comparisonRow(
                mode: .standard,
                icon: "ear.fill",
                summary: L10n.modeGuideStandardSummary
            )
            Divider()
            comparisonRow(
                mode: .highSensitivity,
                icon: "waveform.badge.magnifyingglass",
                summary: L10n.modeGuideHighSensitivitySummary
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func comparisonRow(mode: AcousticMeasurementMode, icon: String, summary: String) -> some View {
        let rowTheme = ModeVisualTheme.theme(for: mode)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(rowTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.segmentLabel)
                    .font(.subheadline.bold())
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
