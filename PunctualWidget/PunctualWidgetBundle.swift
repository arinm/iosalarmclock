import WidgetKit
import SwiftUI

@main
struct PunctualWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextAlarmWidget()
        AlarmLiveActivity()
    }
}
