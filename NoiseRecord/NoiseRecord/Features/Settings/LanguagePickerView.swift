import SwiftUI

struct LanguagePickerView: View {
    @Bindable var appearance: AppAppearanceSettings

    private var measurementMode: AcousticMeasurementMode {
        .standard
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    var body: some View {
        let _ = appearance.languageRefreshID

        List {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    appearance.preferredLanguage = language
                } label: {
                    HStack {
                        Text(language.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if appearance.preferredLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
            }
        }
        .id(appearance.languageRefreshID)
        .observesAppLanguage()
        .navigationTitle(L10n.settingsLanguage)
        .navigationBarTitleDisplayMode(.inline)
    }
}
