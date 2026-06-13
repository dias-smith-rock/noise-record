import UIKit

enum TabBarMonitorIconUpdater {
    private static let monitorTabIndex = 0
    private static weak var cachedTabBarController: UITabBarController?

    private static var idleIcon: UIImage? {
        UIImage(systemName: "waveform")?.withRenderingMode(.alwaysTemplate)
    }

    @MainActor
    static func apply(frame: UIImage?, isAnimating: Bool) {
        let signpost = PerformanceSignpost.begin(.tabBarIconApply)
        defer { PerformanceSignpost.end(.tabBarIconApply, signpost) }

        guard let items = resolvedTabBarController()?.tabBar.items,
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
    static func cacheTabBarController(from root: UIViewController?) {
        cachedTabBarController = root?.findTabBarController()
    }

    @MainActor
    private static func resolvedTabBarController() -> UITabBarController? {
        if let cachedTabBarController {
            return cachedTabBarController
        }
        return UIApplication.shared.connectedScenes
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
