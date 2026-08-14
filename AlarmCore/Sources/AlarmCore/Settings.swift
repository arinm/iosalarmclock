import Foundation

/// Whether an alarm repeats on weekdays or fires once on a specific date.
public enum AlarmMode: String, Codable, Sendable, CaseIterable {
    case recurring
    case oneTimeDate
}

/// Snooze configuration.
public struct SnoozeSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var durationMinutes: Int
    /// RESERVED — persisted and editable, but NOTHING ENFORCES IT YET. Capping
    /// snooze needs the alarm re-armed on each snooze (AlarmKit takes
    /// `postAlert` once, at schedule time), which is a change to the snooze
    /// path deliberately deferred. Don't advertise it as working.
    public var maxCount: Int

    /// Longest snooze the free tier allows. iOS 26's own Clock caps custom
    /// snooze at 15 minutes, so matching it is parity, not a giveaway — Pro
    /// sells what the system CAN'T do, which starts at 16.
    public static let freeCeilingMinutes = 15
    /// Longest snooze anyone can set.
    public static let maxDurationMinutes = 60

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
