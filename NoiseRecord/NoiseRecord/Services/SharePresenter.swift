import UIKit

enum SharePresenter {
    @MainActor
    static func present(items: [Any], onComplete: (() -> Void)? = nil) {
        guard let presenter = topViewController() else { return }

        let activity = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        activity.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activity, animated: true)
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
