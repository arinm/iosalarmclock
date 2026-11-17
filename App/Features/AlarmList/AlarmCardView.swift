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
                                                 title: String(localized: "Alarm on - rings in \(CountdownText.string(until: next, from: .now))", bundle: AppLanguage.bundle),
                                                 subtitle: NotificationActionHandler.describe(next, calendar: .current),
                                                 alarmID: alarm.id)
                                }
                            } else {
                                banners.show(.disabled,
                                             title: String(localized: "Alarm off - won't ring", bundle: AppLanguage.bundle),
                                             subtitle: String(localized: "Until you turn it back on", bundle: AppLanguage.bundle),
                                             alarmID: alarm.id,
                                             undo: { [store] in await store.setEnabled(alarm, true) })
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                ))
                .labelsHidden()
                .accessibilityLabel(alarm.label.isEmpty ? String(localized: "Alarm", bundle: AppLanguage.bundle) : alarm.label)
                .accessibilityValue(alarm.isEnabled ? "On" : "Off")
            }

            RepeatPillsRow(weekdays: alarm.repeatWeekdays, mode: alarm.mode, oneTimeDate: alarm.oneTimeDate)

            statusLine

            // Honest failure surface: the countdown above says when this alarm
            // SHOULD ring, but if the last scheduling pass couldn't hand it to
            // the system there is nothing to ring. Say so instead of letting the
            // card imply an alarm that doesn't exist.
            // (The simulator can't arm AlarmKit alarms, so screenshot mode hides it.)
            if alarm.isEnabled, alarm.lastArmFailed,
               !ProcessInfo.processInfo.arguments.contains("--app-store-screenshots") {
                Label("Couldn't schedule this alarm - it won't ring. Check alarm permission.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.pauseFg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Warning: this alarm could not be scheduled and will not ring")
            }

            // Running snooze: first-class "stop just today" — kills only the
            // pending re-ring; the alarm stays armed for its next occurrence.
            // (Without this, silencing a snooze meant toggling the whole alarm
            // off and back on.)
            if alarm.isEnabled, store.snoozingItemIDs.contains(alarm.id) {
                Button {
                    Task {
                        // Only claim success when the re-ring is confirmed gone —
                        // otherwise say so, rather than showing "stopped" and
                        // letting the button reappear a second later.
                        if await store.stopSnooze(alarm) {
                            let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current, context: .middleOfSentence)
                            banners.show(.neutral,
                                         title: String(localized: "Snooze stopped", bundle: AppLanguage.bundle),
                                         subtitle: String(localized: "Still active - next alarm: \(next)", bundle: AppLanguage.bundle),
                                         alarmID: alarm.id)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } else {
                            banners.show(.disabled,
                                         title: String(localized: "Couldn't stop the snooze", bundle: AppLanguage.bundle),
                                         subtitle: String(localized: "Turn the alarm off to silence it", bundle: AppLanguage.bundle),
                                         alarmID: alarm.id)
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                } label: {
                    Label("Snoozing - stop for today", systemImage: "zzz")
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
                            let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current, context: .middleOfSentence)
                            banners.show(.skip,
                                         title: NotificationActionHandler.skippedTitle(day),
                                         subtitle: String(localized: "Next alarm: \(next)", bundle: AppLanguage.bundle),
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
        guard case .scheduled(let next) = status else { return String(localized: "Skip today", bundle: AppLanguage.bundle) }
        let day = DateOnly(date: next, calendar: .current)
        return String(localized: "Skip \(NotificationActionHandler.dayPhrase(day, calendar: .current))", bundle: AppLanguage.bundle)
    }

    private var timeString: String { TimeText.string(hour: alarm.hour, minute: alarm.minute) }
}

/// Mon–Sun pills, or the date for a one-time alarm.
struct RepeatPillsRow: View {
    @Environment(ThemeManager.self) private var theme
    let weekdays: Set<Weekday>
    let mode: AlarmMode
    let oneTimeDate: DateOnly?

    /// VoiceOver: seven single letters ("M, T, W…") are noise — one label.
    private var pillsAccessibilityLabel: String {
        mode == .oneTimeDate ? oneTimeLabel : String(localized: "Repeats \(weekdays.humanSummary)", bundle: AppLanguage.bundle)
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
        guard let day = oneTimeDate else { return String(localized: "Once", bundle: AppLanguage.bundle) }
        return DayText.short(day)
    }
}
