import SwiftUI

enum SettingsRowMetrics {
    static let verticalPadding: CGFloat = 10
    static let minRowHeight: CGFloat = 22
}

extension View {
    func settingsCardRowPadding() -> some View {
        padding(.vertical, SettingsRowMetrics.verticalPadding)
    }
}

struct SettingsDivider: View {
    let theme: ModeVisualTheme

    var body: some View {
        Divider()
            .overlay(theme.surfaceBorder.opacity(0.65))
    }
}

struct SettingsSectionFooter: View {
    let texts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(texts.indices, id: \.self) { index in
                Text(texts[index])
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .frame(minHeight: SettingsRowMetrics.minRowHeight)
        .settingsCardRowPadding()
    }
}

struct SettingsInlineRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            trailing()
        }
        .frame(minHeight: SettingsRowMetrics.minRowHeight)
        .settingsCardRowPadding()
    }
}

struct SettingsCompoundRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .settingsCardRowPadding()
    }
}

struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    var value: String?
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            SettingsRowLabel(title: title, value: value, showsChevron: true)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsActionRow: View {
    let title: String
    var value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(title: title, value: value, showsChevron: true)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsLinkRow: View {
    let title: String
    var value: String?
    let url: URL

    var body: some View {
        Link(destination: url) {
            SettingsRowLabel(title: title, value: value, showsChevron: true)
        }
    }
}

struct SettingsButtonRow: View {
    let title: String
    var systemImage: String?
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .frame(width: 22)
                }
                Text(title)
                    .font(.subheadline)
                Spacer(minLength: 0)
            }
            .foregroundStyle(role == .destructive ? Color.red : Color.primary)
            .frame(minHeight: SettingsRowMetrics.minRowHeight)
            .settingsCardRowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    var value: String?
    var showsChevron: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: SettingsRowMetrics.minRowHeight)
        .settingsCardRowPadding()
        .contentShape(Rectangle())
    }
}
