import SwiftUI

/// 半屏说明抽屉：完整承接主卡片剥离的模式说明文案。
struct MeasurementModesInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var highSensitivityTheme: ModeVisualTheme { .theme(for: .highSensitivity) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    modeSection(
                        title: L10n.modeSwitchInfoStandardTitle,
                        body: L10n.modeSwitchInfoStandardBody,
                        titleColor: Color.secondary
                    )

                    modeSection(
                        title: L10n.modeSwitchInfoHighSensitivityTitle,
                        body: L10n.modeSwitchInfoHighSensitivityBody,
                        titleColor: highSensitivityTheme.accent
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.modeSwitchInfoTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.gotIt) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func modeSection(title: String, body: String, titleColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(titleColor)

            Text(body)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
