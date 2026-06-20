import SwiftUI

struct FullscreenGuideButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0, next.height > 0 {
            value = next
        }
    }
}

struct FullscreenLEDGuideOverlay: View {
    let theme: ModeVisualTheme
    let buttonFrame: CGRect
    let onDismiss: () -> Void
    var onGuideDismiss: () -> Void = {}
    let onFullscreenTap: () -> Void

    private let scrimOpacity: Double = 0.58
    private let spotlightPadding: CGFloat = 8

    var body: some View {
        GeometryReader { overlayProxy in
            let overlayOrigin = overlayProxy.frame(in: .global).origin
            let localFrame = CGRect(
                x: buttonFrame.minX - overlayOrigin.x,
                y: buttonFrame.minY - overlayOrigin.y,
                width: buttonFrame.width,
                height: buttonFrame.height
            )

            ZStack(alignment: .topLeading) {
                scrim(spotlightRect: spotlightRect(for: localFrame))
                spotlightRing(in: localFrame)
                fullscreenButton(in: localFrame)
                callout(relativeTo: localFrame)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func spotlightRect(for frame: CGRect) -> CGRect {
        frame.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
    }

    private func scrim(spotlightRect: CGRect) -> some View {
        Color.black.opacity(scrimOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Circle()
                    .frame(width: spotlightRect.width, height: spotlightRect.height)
                    .position(x: spotlightRect.midX, y: spotlightRect.midY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }

    private func spotlightRing(in frame: CGRect) -> some View {
        let spotlight = spotlightRect(for: frame)
        return Circle()
            .strokeBorder(theme.accent, lineWidth: 2.5)
            .frame(width: spotlight.width, height: spotlight.height)
            .position(x: spotlight.midX, y: spotlight.midY)
            .allowsHitTesting(false)
    }

    private func fullscreenButton(in frame: CGRect) -> some View {
        Button(action: onFullscreenTap) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(theme.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.dashboardFullscreenLED)
        .position(x: frame.midX, y: frame.midY)
    }

    private func callout(relativeTo frame: CGRect) -> some View {
        let cardSize = calloutCardSize
        let arrowWidth: CGFloat = 10
        let gap: CGFloat = 6
        let centerX = frame.minX - gap - arrowWidth - cardSize.width / 2

        return calloutCard
            .frame(width: cardSize.width, alignment: .leading)
            .overlay(alignment: .trailing) {
                GuideArrowShape(direction: .right)
                    .fill(theme.cardTint)
                    .overlay {
                        GuideArrowShape(direction: .right)
                            .stroke(theme.accent.opacity(0.45), lineWidth: 1)
                    }
                    .frame(width: arrowWidth, height: 14)
                    .offset(x: arrowWidth)
            }
            .position(x: centerX, y: frame.midY)
    }

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.dashboardFullscreenLEDGuide)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Button(L10n.gotIt, action: onGuideDismiss)
                .font(.subheadline.bold())
                .foregroundStyle(theme.accent)
        }
        .padding(14)
        .background(theme.cardTint)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.accent.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    private var calloutCardSize: CGSize {
        CGSize(width: min(236, UIScreen.main.bounds.width - 88), height: 104)
    }
}

private struct GuideArrowShape: Shape {
    enum Direction {
        case right
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY - rect.height / 2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + rect.height / 2))
            path.closeSubpath()
        }
        return path
    }
}
