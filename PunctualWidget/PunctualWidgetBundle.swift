import WidgetKit
import SwiftUI

@main
struct PunctualWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextAlarmWidget()
        AlarmLiveActivity()
        #if canImport(AlarmKit)
        // REQUIRED by AlarmKit whenever an alarm ships a countdown presentation
        // (every snooze-enabled alarm here). Without it the system "may
        // unexpectedly dismiss alarms and fail to alert" — see AlarmKitLiveActivity.
        AlarmKitLiveActivity()
        #endif
    }
}
