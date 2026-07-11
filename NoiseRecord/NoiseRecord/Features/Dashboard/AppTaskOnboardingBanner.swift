import SwiftUI

struct AppTaskOnboardingBanner: View {
    let theme: ModeVisualTheme
    let onDismiss: () -> Void

    private var step: AppTaskOnboardingStep {
        AppOnboardingStore.currentStep
    }

    private var progress: Double {
        switch step {
        case .measure10s:
            min(1, AppOnboardingStore.measureProgressSeconds / AppOnboardingStore.measureTargetSeconds)
        case .visitFiles, .completed:
            1
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.appTaskOnboardingTitle)
                        .font(.subheadline.bold())
                    Text(bannerBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: progress)
                .tint(theme.accent)
        }
        .padding(14)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(theme.surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            AppTelemetry.logProductEvent(
                "onboarding_step_viewed",
                parameters: ["step": step == .measure10s ? "1" : "2"]
            )
        }
    }

    private var bannerBody: String {
        switch step {
        case .measure10s:
            L10n.appTaskOnboardingMeasureBody
        case .visitFiles:
            L10n.appTaskOnboardingFilesBody
        case .completed:
            ""
        }
    }
}
