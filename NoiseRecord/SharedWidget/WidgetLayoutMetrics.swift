import SwiftUI

enum WidgetLayoutMetrics {
    static let contentPadding = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
}

extension View {
    func widgetContentPadding() -> some View {
        padding(WidgetLayoutMetrics.contentPadding)
    }
}
