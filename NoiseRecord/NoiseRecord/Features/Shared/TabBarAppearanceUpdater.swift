import UIKit

enum TabBarAppearanceUpdater {
    private static let monitorTabIndex = 0
    private static let filesTabIndex = 3
    private static let filesBadgeSize: CGFloat = 8
    private static let filesIconCanvasSize = CGSize(width: 27, height: 27)

    private static weak var cachedTabBarController: UITabBarController?
    private static var filesBadgeShouldBeVisible = false
    private static var filesBadgeLayoutRetryCount = 0
    private static let filesBadgeMaxLayoutRetries = 6

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
        reapplyFilesBadgeIfNeeded()
    }

    @MainActor
    static func setFilesBadgeVisible(_ visible: Bool) {
        filesBadgeShouldBeVisible = visible
        applyFilesBadgeNow()
    }

    @MainActor
    static func reapplyFilesBadgeIfNeeded() {
        guard filesBadgeShouldBeVisible else { return }
        applyFilesBadgeNow()
    }

    @MainActor
    private static func applyFilesBadgeNow() {
        guard let items = tabBarItems(),
              filesTabIndex < items.count else {
            if filesBadgeShouldBeVisible {
                scheduleFilesBadgeLayoutRetry()
            }
            return
        }

        filesBadgeLayoutRetryCount = 0
        items[filesTabIndex].badgeValue = nil
        applyFilesTabIcons(to: items[filesTabIndex], showBadge: filesBadgeShouldBeVisible)
    }

    @MainActor
    private static func applyFilesTabIcons(to item: UITabBarItem, showBadge: Bool) {
        if showBadge {
            item.image = filesTabIcon(showBadge: true, selected: false)
            item.selectedImage = filesTabIcon(showBadge: true, selected: true)
        } else {
            let icon = UIImage(systemName: "list.bullet")?.withRenderingMode(.alwaysTemplate)
            item.image = icon
            item.selectedImage = icon
        }
    }

    @MainActor
    private static func filesTabIcon(showBadge: Bool, selected: Bool) -> UIImage? {
        let pointSize: CGFloat = 22
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let symbol = UIImage(systemName: "list.bullet", withConfiguration: config) else {
            return nil
        }

        guard showBadge else {
            return symbol.withRenderingMode(.alwaysTemplate)
        }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: filesIconCanvasSize, format: format)
        let symbolColor = selected ? UIColor.systemBlue : UIColor.secondaryLabel

        return renderer.image { _ in
            let symbolSize = symbol.size
            let symbolOrigin = CGPoint(
                x: (filesIconCanvasSize.width - symbolSize.width) / 2,
                y: (filesIconCanvasSize.height - symbolSize.height) / 2 + 1
            )
            symbol.withTintColor(symbolColor, renderingMode: .alwaysOriginal)
                .draw(at: symbolOrigin)

            let dotRect = CGRect(
                x: filesIconCanvasSize.width - filesBadgeSize + 1,
                y: 2,
                width: filesBadgeSize,
                height: filesBadgeSize
            )
            UIColor.systemRed.setFill()
            UIBezierPath(ovalIn: dotRect).fill()
        }
        .withRenderingMode(.alwaysOriginal)
    }

    @MainActor
    private static func scheduleFilesBadgeLayoutRetry() {
        guard filesBadgeShouldBeVisible,
              filesBadgeLayoutRetryCount < filesBadgeMaxLayoutRetries else { return }

        filesBadgeLayoutRetryCount += 1
        let delay = DispatchTime.now() + .milliseconds(120 * filesBadgeLayoutRetryCount)
        DispatchQueue.main.asyncAfter(deadline: delay) {
            guard filesBadgeShouldBeVisible else { return }
            setFilesBadgeVisible(true)
        }
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
