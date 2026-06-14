import WidgetKit
import SwiftUI

@main
struct DecibelProWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiveMeterWidget()
        SessionStatsWidget()
        MonitoringControlWidget()
    }
}
