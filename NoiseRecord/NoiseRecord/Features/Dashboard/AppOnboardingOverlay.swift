import SwiftUI

struct AppOnboardingOverlay: View {
    let theme: ModeVisualTheme
    let onComplete: () -> Void

    @State private var stepIndex = 0

    private var steps: [OnboardingStep] {
        [
            OnboardingStep(
                systemImage: "gauge.with.dots.needle.67percent",
                title: L10n.appOnboardingStepMeasureTitle,
                body: L10n.appOnboardingStepMeasureBody
            ),
            OnboardingStep(
                systemImage: "moon.stars.fill",
                title: L10n.appOnboardingStepSleepTitle,
                body: L10n.appOnboardingStepSleepBody
            ),
            OnboardingStep(
                systemImage: "doc.richtext",
                title: L10n.appOnboardingStepExportTitle,
                body: L10n.appOnboardingStepExportBody
            ),
        ]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 18) {
                Image(systemName: steps[stepIndex].systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(theme.accent)

                Text(steps[stepIndex].title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(steps[stepIndex].body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == stepIndex ? theme.accent : Color.secondary.opacity(0.35))
                            .frame(width: 8, height: 8)
                    }
                }

                Button(action: advance) {
                    Text(stepIndex == steps.count - 1 ? L10n.gotIt : L10n.paywallContinue)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                Button(L10n.skip, action: complete)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    private func advance() {
        if stepIndex < steps.count - 1 {
            stepIndex += 1
            AppTelemetry.logProductEvent(
                "onboarding_step_viewed",
                parameters: ["step": String(stepIndex + 1)]
            )
        } else {
            complete()
        }
    }

    private func complete() {
        AppTelemetry.logProductEvent(
            "onboarding_dismissed",
            parameters: ["method": "completed"]
        )
        onComplete()
    }
}

private struct OnboardingStep {
    let systemImage: String
    let title: String
    let body: String
}
