import SwiftUI

/// Compact Monitor → Evidence shortcut (not a hero CTA).
struct VideoEvidenceEntrySection: View {
    let theme: ModeVisualTheme
    let onOpen: () -> Void

    var body: some View {
        Button {
            AppTelemetry.logProductEvent("dashboard_video_evidence_tap")
            onOpen()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "video.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.dashboardVideoEvidenceActionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(L10n.dashboardVideoEvidenceActionBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.cardTint)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.surfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.dashboardVideoEvidenceActionTitle)
    }
}
