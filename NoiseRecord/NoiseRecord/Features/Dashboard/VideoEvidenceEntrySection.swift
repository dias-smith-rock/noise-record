import SwiftUI

struct VideoEvidenceEntrySection: View {
    let theme: ModeVisualTheme
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.dashboardVideoEvidenceTitle)
                .font(.headline)

            Text(L10n.dashboardVideoEvidenceSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProCard(theme: theme) {
                Button {
                    AppTelemetry.logProductEvent("dashboard_video_evidence_tap")
                    onOpen()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.dashboardVideoEvidenceActionTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(L10n.dashboardVideoEvidenceActionBody)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
