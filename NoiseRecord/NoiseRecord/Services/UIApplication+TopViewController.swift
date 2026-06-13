import UIKit

extension UIApplication {
    var topViewController: UIViewController? {
        let scenes = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        for scene in scenes {
            guard let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { continue }
            return Self.topViewController(from: root)
        }

        if let root = connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow)?.rootViewController })
            .first {
            return Self.topViewController(from: root)
        }

        return nil
    }

    private static func topViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return controller
    }
}
