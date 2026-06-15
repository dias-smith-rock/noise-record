import SwiftUI

// MARK: - Page chrome

struct ProPageBackground: View {
    let theme: ModeVisualTheme

    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

struct ProSectionHeader: View {
    let title: String
    var subtitle: String?
    var theme: ModeVisualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProCard<Content: View>: View {
    let theme: ModeVisualTheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .background(theme.cardTint)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.surfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProMetricCard: View {
    let title: String
    let value: String
    var theme: ModeVisualTheme

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ProPrimaryButton: View {
    let title: String
    let systemImage: String
    var tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

struct ProToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var theme: ModeVisualTheme
    var icon: String = "switch.2"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(theme.accent)
        }
    }
}

struct ProSliderRow: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    var unit: String = "dB"
    var theme: ModeVisualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
            }
            Slider(value: $value, in: range, step: step)
                .tint(theme.accent)
        }
    }
}

struct ProChip: View {
    let text: String
    var theme: ModeVisualTheme
    var isSelected: Bool = false

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? theme.accent : Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }
}

struct ProRecordingStatusBadge: View {
    let state: RecordingState
    var theme: ModeVisualTheme

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 10, height: 10)
                .shadow(color: indicatorColor.opacity(0.6), radius: state == .recording ? 4 : 0)
            Text(statusText)
                .font(.subheadline.bold())
                .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.cardTint)
        .overlay(
            Capsule().strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var indicatorColor: Color {
        switch state {
        case .idle: .gray
        case .recording: .red
        case .coolingDown: theme.accent
        }
    }

    private var statusText: String {
        state.localizedStatusText
    }
}

struct ProEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    var theme: ModeVisualTheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Tab header

/// 已购永久免广告时，显示在 Tab 标题右侧的标识。
struct ProTabNoAdsBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.caption2.weight(.semibold))
            Text(L10n.noAdsBadge)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.14))
        .clipShape(Capsule())
        .accessibilityLabel(L10n.noAdsBadge)
    }
}

struct ProTabHeader<Trailing: View>: View {
    let title: String
    var theme: ModeVisualTheme
    @ViewBuilder var trailing: () -> Trailing

    @Bindable private var iap = IAPManager.shared

    init(
        title: String,
        theme: ModeVisualTheme,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.theme = theme
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.title3.bold())
                    .lineLimit(1)

                if iap.isAdsRemoved {
                    ProTabNoAdsBadge()
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

extension ProTabHeader where Trailing == EmptyView {
    init(title: String, theme: ModeVisualTheme) {
        self.init(title: title, theme: theme) { EmptyView() }
    }
}

struct ProTabHeaderIconButton<MenuContent: View>: View {
    let systemImage: String
    let theme: ModeVisualTheme
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 36, height: 36)
                .background(theme.badgeBackground)
                .clipShape(Circle())
        }
    }
}

struct ProTabHeaderCapsuleButton: View {
    let title: String
    let theme: ModeVisualTheme
    var systemImage: String?
    var isProminent: Bool = false
    var prominentColor: Color = .red
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? .white : theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isProminent ? prominentColor : theme.badgeBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

struct ProTabHeaderTextButton: View {
    let title: String
    var theme: ModeVisualTheme?
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme?.accent ?? .primary)
    }
}

struct ProFloatingActionButton: View {
    let title: String
    let systemImage: String
    let theme: ModeVisualTheme
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(isDestructive ? Color.red : theme.accent)
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func proTabBackground(theme: ModeVisualTheme) -> some View {
        background(ProPageBackground(theme: theme))
    }

    func proTabNavigationChrome() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }
}
