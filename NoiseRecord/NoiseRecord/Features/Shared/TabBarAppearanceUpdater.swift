import UIKit

enum TabBarAppearanceUpdater {
    private static let monitorTabIndex = 0
    private static let filesTabIndex = 3
    private static let filesBadgeTag = 90_421
    private static let filesBadgeSize: CGFloat = 6

    private static weak var cachedTabBarController: UITabBarController?

    @MainActor
    static func cacheTabBarController(from root: UIViewController?) {
        if let controller = root?.findTabBarController() {
            cachedTabBarController = controller
        }
    }

    @MainActor
    static func tabBarItems() -> [UITabBarItem]? {
        resolvedTabBarController()?.tabBar.items
    }

    @MainActor
    static func applyTabTitles() {
        guard let items = tabBarItems(),
              items.count > filesTabIndex else { return }

        items[monitorTabIndex].title = L10n.tabMonitor
        items[1].title = L10n.tabVoice
        items[2].title = L10n.tabVideo
        items[filesTabIndex].title = L10n.tabFiles
        items[4].title = L10n.tabSettings
    }

    @MainActor
    static func setFilesBadgeVisible(_ visible: Bool) {
        guard let controller = resolvedTabBarController(),
              let items = controller.tabBar.items,
              filesTabIndex < items.count else { return }

        items[filesTabIndex].badgeValue = nil
        removeCustomFilesBadge(from: controller.tabBar)

        guard visible else { return }

        guard let button = tabBarButton(at: filesTabIndex, in: controller.tabBar) else { return }

        let dot = UIView()
        dot.tag = filesBadgeTag
        dot.backgroundColor = .systemRed
        dot.layer.cornerRadius = filesBadgeSize / 2
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.isUserInteractionEnabled = false
        button.addSubview(dot)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: filesBadgeSize),
            dot.heightAnchor.constraint(equalToConstant: filesBadgeSize),
            dot.topAnchor.constraint(equalTo: button.topAnchor, constant: 6),
            dot.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -10),
        ])
    }

    @MainActor
    private static func removeCustomFilesBadge(from tabBar: UITabBar) {
        tabBar.subviews
            .flatMap { $0.subviews }
            .first { $0.tag == filesBadgeTag }?
            .removeFromSuperview()
    }

    @MainActor
    private static func tabBarButton(at index: Int, in tabBar: UITabBar) -> UIView? {
        let buttons = tabBar.subviews
            .filter { NSStringFromClass(type(of: $0)).contains("UITabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard index < buttons.count else { return nil }
        return buttons[index]
    }

    @MainActor
    private static func resolvedTabBarController() -> UITabBarController? {
        if let cachedTabBarController,
           cachedTabBarController.view.window != nil,
           let items = cachedTabBarController.tabBar.items,
           !items.isEmpty {
            return cachedTabBarController
        }

        let fresh = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .findTabBarController()

        if let fresh {
            cachedTabBarController = fresh
        }
        return fresh
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
