import UIKit

enum TabBarAppearanceUpdater {
    private static let monitorTabIndex = 0
    private static let filesTabIndex = 3
    private static let filesBadgeTag = 90_421
    private static let filesBadgeSize: CGFloat = 6

    private static weak var cachedTabBarController: UITabBarController?
    private static var filesBadgeShouldBeVisible = false
    private static var filesBadgeLayoutRetryScheduled = false

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
        filesBadgeShouldBeVisible = visible

        guard let controller = resolvedTabBarController(),
              let items = controller.tabBar.items,
              filesTabIndex < items.count else { return }

        let tabBar = controller.tabBar
        items[filesTabIndex].badgeValue = nil
        removeCustomFilesBadge(from: tabBar)

        guard visible else { return }

        tabBar.layoutIfNeeded()

        guard let button = tabBarButton(at: filesTabIndex, in: tabBar) else {
            scheduleFilesBadgeLayoutRetry()
            return
        }

        let dot = UIView()
        dot.tag = filesBadgeTag
        dot.backgroundColor = .systemRed
        dot.layer.cornerRadius = filesBadgeSize / 2
        dot.isUserInteractionEnabled = false

        let anchor = button.convert(
            CGPoint(x: button.bounds.maxX - 10, y: 6),
            to: tabBar
        )
        dot.frame = CGRect(
            x: anchor.x - filesBadgeSize / 2,
            y: anchor.y - filesBadgeSize / 2,
            width: filesBadgeSize,
            height: filesBadgeSize
        )
        tabBar.addSubview(dot)
    }

    @MainActor
    private static func scheduleFilesBadgeLayoutRetry() {
        guard !filesBadgeLayoutRetryScheduled else { return }
        filesBadgeLayoutRetryScheduled = true
        DispatchQueue.main.async {
            filesBadgeLayoutRetryScheduled = false
            guard filesBadgeShouldBeVisible else { return }
            setFilesBadgeVisible(true)
        }
    }

    @MainActor
    private static func removeCustomFilesBadge(from tabBar: UITabBar) {
        for subview in tabBar.subviews where subview.tag == filesBadgeTag {
            subview.removeFromSuperview()
        }

        tabBar.subviews
            .flatMap(\.subviews)
            .filter { $0.tag == filesBadgeTag }
            .forEach { $0.removeFromSuperview() }
    }

    @MainActor
    private static func tabBarButton(at index: Int, in tabBar: UITabBar) -> UIView? {
        let buttons = collectTabBarButtons(in: tabBar)
            .sorted { $0.frame.minX < $1.frame.minX }
        guard index < buttons.count else { return nil }
        return buttons[index]
    }

    @MainActor
    private static func collectTabBarButtons(in view: UIView) -> [UIView] {
        var buttons: [UIView] = []
        for subview in view.subviews {
            if NSStringFromClass(type(of: subview)).contains("UITabBarButton") {
                buttons.append(subview)
            } else {
                buttons.append(contentsOf: collectTabBarButtons(in: subview))
            }
        }
        return buttons
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
