import SwiftUI

// MARK: - Page chrome

struct ProPageBackground: View {
    let theme: ModeVisualTheme

    var body: some View {
        LinearGradient(
            colors: [theme.cardTint, Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
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
                    .foregroundStyle(theme.accent.opacity(0.85))
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
                    .strokeBorder(theme.accent.opacity(0.22), lineWidth: 1)
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
                .foregroundStyle(theme.accent.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.accent.opacity(0.15), lineWidth: 1)
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
            .foregroundStyle(isSelected ? .white : theme.accent)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [theme.accent, theme.secondaryAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    theme.badgeBackground
                }
            }
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
            Capsule().strokeBorder(theme.accent.opacity(0.25), lineWidth: 1)
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
        switch state {
        case .idle: "声控待机中"
        case .recording: "正在自动录音"
        case .coolingDown: "尾音延迟中"
        }
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accent, theme.secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                .strokeBorder(theme.accent.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension View {
    func proTabBackground(theme: ModeVisualTheme) -> some View {
        background(ProPageBackground(theme: theme))
    }
}
