import SwiftUI
import AlarmCore

/// A single premium alarm card. Shows time, label, repeat pills, toggle, and the
/// always-present status line (countdown / skipped / paused / off). Expands to a
/// first-class **Skip today** button — never buried in a menu.
struct AlarmCardView: View {
    @Bindable var alarm: AlarmItem
    let now: Date
    @Environment(AlarmStore.self) private var store
    @Environment(BannerCenter.self) private var banners
    /// Scales the big time with the user's Dynamic Type setting (fixed 44pt
    /// would stay frozen while every label around it grows), capped so
    /// accessibility sizes don't blow up the card layout.
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 44

    private var status: AlarmStatus { alarm.status(now: now) }
    private var presented: (text: String, tint: Color, fg: Color) { StatusPresenter.line(status, now: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeString)
                        .font(.system(size: min(timeSize, 64), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                    if !alarm.label.isEmpty {
                        Text(alarm.label).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { newValue in
                        Task {
                            await store.setEnabled(alarm, newValue)
                            if newValue {
                                // Confirm ON with the engine-computed next ring,
                                // symmetric with the "Alarm set" banner.
                                if let next = alarm.nextOccurrence {
                                    banners.show(.neutral,
                                                 title: "Alarm on — rings in \(CountdownFormatter.string(until: next, from: .now))",
                                                 subtitle: NotificationActionHandler.describe(next, calendar: .current),
                                                 alarmID: alarm.id)
                                }
                            } else {
                                banners.show(.disabled,
                                             title: "Alarm off — won't ring",
                                             subtitle: "Until you turn it back on",
                                             alarmID: alarm.id,
                                             undo: { [store] in await store.setEnabled(alarm, true) })
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                ))
                .labelsHidden()
                .accessibilityLabel(alarm.label.isEmpty ? "Alarm" : alarm.label)
                .accessibilityValue(alarm.isEnabled ? "On" : "Off")
            }

            RepeatPillsRow(weekdays: alarm.repeatWeekdays, mode: alarm.mode, oneTimeDate: alarm.oneTimeDate)

            statusLine

            // Running snooze: first-class "stop just today" — kills only the
            // pending re-ring; the alarm stays armed for its next occurrence.
            // (Without this, silencing a snooze meant toggling the whole alarm
            // off and back on.)
            if alarm.isEnabled, store.snoozingItemIDs.contains(alarm.id) {
                Button {
                    Task {
                        await store.stopSnooze(alarm)
                        let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current)
                        banners.show(.neutral,
                                     title: "Snooze stopped",
                                     subtitle: "Still active — next alarm: \(next)",
                                     alarmID: alarm.id)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } label: {
                    Label("Snoozing — stop for today", systemImage: "zzz")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.pauseFg)
            }

            if shouldShowSkip {
                Button {
                    Task {
                        if let day = await store.skipNextOccurrence(alarm) {
                            let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current)
                            banners.show(.skip,
                                         title: "Skipped \(NotificationActionHandler.dayPhrase(day, calendar: .current)) — still active",
                                         subtitle: "Next alarm: \(next)",
                                         alarmID: alarm.id,
                                         undo: { [store] in await store.unskip(alarm, day: day) })
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } label: {
                    Label(skipButtonTitle, systemImage: "forward.end.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Theme.skipFg)
            }
        }
        .punctualCard()
        // Recede the *content* when off (handled per-element via .secondary), but
        // keep the card surface at full opacity so it never looks like a glitch.
        .saturation(alarm.isEnabled ? 1 : 0)
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon).font(.caption)
            Text(presented.text).font(.subheadline.weight(.medium))
            if alarm.preAlert.isEnabled, case .scheduled = status {
                Spacer()
                Label("\(alarm.preAlert.minutesBefore)m", systemImage: "bell.badge")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(presented.fg)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(presented.tint, in: RoundedRectangle(cornerRadius: Theme.radiusInner, style: .continuous))
    }

    private var statusIcon: String {
        switch status {
        case .off: "bell.slash"
        case .completed: "checkmark.circle"
        case .noUpcoming: "questionmark.circle"
        case .scheduled: "alarm"
        case .skippedToday: "forward.end"
        case .paused: "pause.circle"
        }
    }

    /// Offer the first-class skip whenever the next ring is within 24h — the
    /// real decision moment is THE EVENING BEFORE ("no work tomorrow"), which
    /// today-only gating missed entirely. Uses the TimelineView-driven `now` so
    /// the button appears/disappears live. One-time alarms are excluded:
    /// "skipping" one never-rings it, so "Skipped — still active" would lie —
    /// the toggle (and the context menu) are the honest affordances there.
    private var shouldShowSkip: Bool {
        guard alarm.mode != .oneTimeDate, case .scheduled(let next) = status else { return false }
        return next.timeIntervalSince(now) <= 24 * 3600
    }

    /// "Skip today" / "Skip tomorrow" — routed through dayPhrase so a weekday
    /// name is correct by construction if the window ever widens.
    private var skipButtonTitle: String {
        guard case .scheduled(let next) = status else { return "Skip today" }
        let day = DateOnly(date: next, calendar: .current)
        return "Skip \(NotificationActionHandler.dayPhrase(day, calendar: .current))"
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.locale?.is24Hour == true ? "HH:mm" : "h:mm a"
        var comps = DateComponents(); comps.hour = alarm.hour; comps.minute = alarm.minute
        let date = Calendar.current.date(from: comps) ?? .now
        return f.string(from: date)
    }
}

/// Mon–Sun pills, or the date for a one-time alarm.
struct RepeatPillsRow: View {
    @Environment(ThemeManager.self) private var theme
    let weekdays: Set<Weekday>
    let mode: AlarmMode
    let oneTimeDate: DateOnly?

    /// VoiceOver: seven single letters ("M, T, W…") are noise — one label.
    private var pillsAccessibilityLabel: String {
        mode == .oneTimeDate ? oneTimeLabel : "Repeats \(weekdays.humanSummary)"
    }

    var body: some View {
        pills
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(pillsAccessibilityLabel)
    }

    @ViewBuilder
    private var pills: some View {
        if mode == .oneTimeDate {
            Label(oneTimeLabel, systemImage: "calendar")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        } else {
            // Empty set == the engine fires EVERY day, so light all pills up —
            // seven dim pills would read as the opposite of what happens.
            let effective = weekdays.isEmpty ? Set(Weekday.allCases) : weekdays
            HStack(spacing: 6) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Text(day.minimalLabel)
                        .font(.caption2.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(effective.contains(day) ? theme.accentColor.opacity(0.22) : Color.clear, in: Circle())
                        .foregroundStyle(effective.contains(day) ? theme.accentColor : .secondary)
                }
            }
        }
    }

    private var oneTimeLabel: String {
        guard let day = oneTimeDate, let date = day.startOfDay(in: .current) else { return "Once" }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }
}

private extension Locale {
    var is24Hour: Bool {
        guard let fmt = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: self) else { return false }
        return !fmt.contains("a")
    }
}
