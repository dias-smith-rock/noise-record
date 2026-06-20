import SwiftUI
import UIKit

/// 嵌入全屏 SwiftUI 视图，向系统声明当前呈现层支持横屏。
struct LandscapeOrientationEnforcer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> LandscapeEnforcingViewController {
        LandscapeEnforcingViewController()
    }

    func updateUIViewController(_ uiViewController: LandscapeEnforcingViewController, context: Context) {}
}

final class LandscapeEnforcingViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }

    override var shouldAutorotate: Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        InterfaceOrientationLocker.enterLandscapeFullscreen()
    }
}
