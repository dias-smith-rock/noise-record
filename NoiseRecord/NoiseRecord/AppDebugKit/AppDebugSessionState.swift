import Foundation

#if DEBUG
/// Tracks the current UI node and a dismiss stack so MCP exploration can DFS + `system.back`.
@MainActor
final class AppDebugSessionState {
    static let shared = AppDebugSessionState()

    private struct Frame {
        let id: String
        let dismiss: () -> Void
    }

    private(set) var viewID: String = "app.root"
    private(set) var tab: String = "monitor"
    private var stack: [Frame] = []
    /// Called when the stack is empty: typically return to Monitor tab / dismiss root sheets.
    var returnToRoot: (() -> Void)?

    private init() {}

    func setTab(_ tab: String, viewID: String) {
        self.tab = tab
        if stack.isEmpty {
            self.viewID = viewID
        }
    }

    func setView(_ viewID: String) {
        self.viewID = viewID
    }

    func push(id: String, dismiss: @escaping () -> Void) {
        // Avoid duplicate frames when SwiftUI re-appears the same presentation.
        if stack.last?.id == id { return }
        stack.append(Frame(id: id, dismiss: dismiss))
        viewID = id
    }

    /// Drop a frame after UI-driven dismiss without invoking `dismiss` again.
    func removeIfPresent(id: String) {
        guard let index = stack.lastIndex(where: { $0.id == id }) else { return }
        stack.remove(at: index)
        viewID = stack.last?.id ?? rootViewID
    }

    @discardableResult
    func back() -> Bool {
        if let top = stack.popLast() {
            viewID = stack.last?.id ?? rootViewID
            top.dismiss()
            return true
        }
        if PaywallPresenter.shared.isPresented {
            PaywallPresenter.shared.resolve(purchased: false)
            return true
        }
        returnToRoot?()
        return true
    }

    private var rootViewID: String {
        "tab.\(tab)"
    }

    func snapshot() -> [String: Any] {
        [
            "status": "ok",
            "view_id": viewID,
            "tab": tab,
            "presented": stack.map(\.id),
            "paywall_presented": PaywallPresenter.shared.isPresented,
            "actions": AppDebugActionRegistry.shared.availableActions(),
        ]
    }
}
#endif
