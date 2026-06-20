import UIKit

/// 全屏 LED 看板进入/退出时的横竖屏约束。
@MainActor
enum InterfaceOrientationLocker {
    private static let landscapeRetryDelaysMs: [UInt64] = [0, 120, 300, 600]

    static var supportedMask: UIInterfaceOrientationMask = [
        .portrait,
        .landscapeLeft,
        .landscapeRight,
    ]

    static func enterLandscapeFullscreen() {
        supportedMask = .landscape
        scheduleLandscapeActivation()
    }

    static func exitLandscapeFullscreen() {
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        requestOrientationUpdate(preferred: .portrait)
    }

    private static func scheduleLandscapeActivation() {
        for delayMs in landscapeRetryDelaysMs {
            Task { @MainActor in
                if delayMs > 0 {
                    try? await Task.sleep(for: .milliseconds(delayMs))
                }
                requestOrientationUpdate(preferred: .landscapeRight)
            }
        }
    }

    private static func requestOrientationUpdate(preferred: UIInterfaceOrientation) {
        let orientations: UIInterfaceOrientationMask = preferred.isLandscape
            ? .landscape
            : .portrait

        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
        }

        invalidateOrientationChain(from: UIApplication.shared.topViewController)

        if UIDevice.current.orientation.isLandscape != preferred.isLandscape {
            UIDevice.current.setValue(preferred.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }

    private static func invalidateOrientationChain(from controller: UIViewController?) {
        var current = controller
        while let controller = current {
            controller.setNeedsUpdateOfSupportedInterfaceOrientations()
            if let parent = controller.parent {
                current = parent
            } else if let presenting = controller.presentingViewController {
                current = presenting
            } else {
                current = nil
            }
        }
    }
}
