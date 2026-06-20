import SwiftUI

struct AccentColorSettingsView: View {
    @Bindable var appearance: AppAppearanceSettings

    var body: some View {
        let _ = appearance.accentRefreshID

        Form {
            modeAccentSection(
                mode: .standard,
                preference: $appearance.standardAccentPreference
            )

            modeAccentSection(
                mode: .highSensitivity,
                preference: $appearance.highSensitivityAccentPreference
            )
        }
        .observesAppLanguage()
        .navigationTitle(L10n.settingsAccentColor)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func modeAccentSection(
        mode: AcousticMeasurementMode,
        preference: Binding<ModeAccentPreference>
    ) -> some View {
        let theme = ModeVisualTheme.theme(for: mode)

        Section {
            Picker(L10n.settingsAccentColorSource, selection: choiceBinding(preference)) {
                ForEach(AccentColorChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            if preference.wrappedValue.choice == .preset {
                presetGrid(preference: preference, theme: theme)
            }

            if preference.wrappedValue.choice == .custom {
                ColorPicker(
                    L10n.settingsAccentCustom,
                    selection: customColorBinding(preference),
                    supportsOpacity: false
                )
            }

            accentPreview(theme: theme)
        } header: {
            Text(mode.userFacingTitle)
        }
    }

    private func choiceBinding(_ preference: Binding<ModeAccentPreference>) -> Binding<AccentColorChoice> {
        Binding(
            get: { preference.wrappedValue.choice },
            set: { newChoice in
                var updated = preference.wrappedValue
                updated.choice = newChoice
                preference.wrappedValue = updated
            }
        )
    }

    private func customColorBinding(_ preference: Binding<ModeAccentPreference>) -> Binding<Color> {
        Binding(
            get: { preference.wrappedValue.customRGB.color },
            set: { newColor in
                var updated = preference.wrappedValue
                updated.customRGB = StoredRGB(color: newColor)
                preference.wrappedValue = updated
            }
        )
    }

    private func presetGrid(
        preference: Binding<ModeAccentPreference>,
        theme: ModeVisualTheme
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
            ForEach(AppAccentPreset.allCases) { preset in
                Button {
                    var updated = preference.wrappedValue
                    updated.preset = preset
                    preference.wrappedValue = updated
                } label: {
                    ZStack {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 40, height: 40)

                        if preference.wrappedValue.preset == preset {
                            Circle()
                                .strokeBorder(theme.accent, lineWidth: 3)
                                .frame(width: 46, height: 46)

                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .shadow(radius: 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .accessibilityLabel(preset.displayName)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func accentPreview(theme: ModeVisualTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.settingsAccentPreview)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text("dB")
                    .font(.caption.bold())
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.badgeBackground)
                    .clipShape(Capsule())

                Text("72")
                    .font(.headline.bold())
                    .foregroundStyle(theme.accent)

                Spacer()

                Image(systemName: "waveform")
                    .font(.body)
                    .foregroundStyle(theme.accent)
            }
            .padding(12)
            .background(theme.cardTint)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.surfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 4)
    }
}
