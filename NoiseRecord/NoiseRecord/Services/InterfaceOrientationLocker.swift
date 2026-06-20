import UIKit

/// 全屏 LED 看板进入/退出时的横竖屏约束。
@MainActor
enum InterfaceOrientationLocker {
    static var supportedMask: UIInterfaceOrientationMask = [
        .portrait,
        .landscapeLeft,
        .landscapeRight,
    ]

    static func enterLandscapeFullscreen() {
        supportedMask = .landscape
        requestOrientationUpdate(preferred: .landscapeRight)
    }

    static func exitLandscapeFullscreen() {
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        requestOrientationUpdate(preferred: .portrait)
    }

    private static func requestOrientationUpdate(preferred: UIInterfaceOrientation) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        let orientations: UIInterfaceOrientationMask = preferred.isLandscape
            ? .landscape
            : .portrait

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }

        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        UIDevice.current.setValue(preferred.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
