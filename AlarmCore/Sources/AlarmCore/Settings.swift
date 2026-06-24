import Foundation

/// Whether an alarm repeats on weekdays or fires once on a specific date.
public enum AlarmMode: String, Codable, Sendable, CaseIterable {
    case recurring
    case oneTimeDate
}

/// Snooze configuration. `maxCount` caps how many times the user may snooze
/// before the alarm stops offering it.
public struct SnoozeSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var durationMinutes: Int
    public var maxCount: Int

    public init(isEnabled: Bool = true, durationMinutes: Int = 9, maxCount: Int = 3) {
        self.isEnabled = isEnabled
        self.durationMinutes = max(1, durationMinutes)
        self.maxCount = max(0, maxCount)
    }

    public static let `default` = SnoozeSettings()
}

/// Pre-alert ("heads-up") configuration. This drives the local notification, not
/// the AlarmKit alarm itself.
public struct PreAlertSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var minutesBefore: Int

    public init(isEnabled: Bool = true, minutesBefore: Int = 15) {
        self.isEnabled = isEnabled
        self.minutesBefore = max(1, minutesBefore)
    }

    public static let `default` = PreAlertSettings()
}
