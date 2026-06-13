import UIKit

enum TabBarMonitorIconUpdater {
    private static let monitorTabIndex = 0

    private static var idleIcon: UIImage? {
        UIImage(systemName: "waveform")?.withRenderingMode(.alwaysTemplate)
    }

    @MainActor
    static func apply(frame: UIImage?, isAnimating: Bool) {
        guard let items = tabBarController()?.tabBar.items,
              monitorTabIndex < items.count else { return }

        let icon: UIImage?
        if isAnimating {
            icon = frame ?? idleIcon
        } else {
            icon = idleIcon
        }

        items[monitorTabIndex].image = icon
        items[monitorTabIndex].selectedImage = icon
    }

    @MainActor
    private static func tabBarController() -> UITabBarController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .findTabBarController()
    }
}

private extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let tabBarController = self as? UITabBarController {
            return tabBarController
        }

        for child in children {
            if let tabBarController = child.findTabBarController() {
                return tabBarController
            }
        }

        return presentedViewController?.findTabBarController()
    }
}
