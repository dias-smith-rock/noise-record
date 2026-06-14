import UIKit

enum TabBarMonitorIconUpdater {
    private static let monitorTabIndex = 0

    private static var idleIcon: UIImage? {
        UIImage(systemName: "waveform")?.withRenderingMode(.alwaysTemplate)
    }

    @MainActor
    static func apply(frame: UIImage?, isAnimating: Bool) {
        let signpost = PerformanceSignpost.begin(.tabBarIconApply)
        defer { PerformanceSignpost.end(.tabBarIconApply, signpost) }

        guard let items = TabBarAppearanceUpdater.tabBarItems(),
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
}
