import SwiftUI

struct EvidenceMetricRow: View {
    let title: String
    var subtitle: String?
    let value: String
    var infoText: String?
    var theme: ModeVisualTheme

    @State private var showInfo = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .multilineTextAlignment(.trailing)

            if infoText != nil {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.mediaDetailMetricInfoAccessibility)
            }
        }
        .padding(.vertical, 10)
        .sheet(isPresented: $showInfo) {
            if let infoText {
                NavigationStack {
                    ScrollView {
                        Text(infoText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.done) { showInfo = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct EvidenceMetricSection<Content: View>: View {
    let title: String
    var theme: ModeVisualTheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProSectionHeader(title: title, theme: theme)
            ProCard(theme: theme) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }
}

struct EvidenceConfigRow: View {
    let title: String
    let value: String
    var infoText: String?
    var theme: ModeVisualTheme

    var body: some View {
        EvidenceMetricRow(
            title: title,
            value: value,
            infoText: infoText,
            theme: theme
        )
    }
}

struct EvidenceNotesEditor: View {
    @Binding var notes: String
    var theme: ModeVisualTheme
    var onCommit: () -> Void

    var body: some View {
        ProCard(theme: theme) {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(L10n.mediaDetailNotesPlaceholder)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $notes)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .onChange(of: notes) { _, _ in
                        onCommit()
                    }
            }
        }
    }
}
