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

    private var status: AlarmStatus { alarm.status(now: now) }
    private var presented: (text: String, tint: Color, fg: Color) { StatusPresenter.line(status, now: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeString)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
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
                            // Confirm the less-reversible action just as loudly as skip.
                            if newValue {
                                banners.show(.enabled, title: "Alarm on")
                            } else {
                                banners.show(.disabled,
                                             title: "Alarm off — won't ring",
                                             subtitle: "Until you turn it back on",
                                             undo: { [store] in await store.setEnabled(alarm, true) })
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                ))
                .labelsHidden()
            }

            RepeatPillsRow(weekdays: alarm.repeatWeekdays, mode: alarm.mode, oneTimeDate: alarm.oneTimeDate)

            statusLine

            if shouldShowSkip {
                Button {
                    Task { await store.skipNextOccurrence(alarm) }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Skip today", systemImage: "forward.end.fill")
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

    /// Only offer skip when there's a natural occurrence today to skip.
    private var shouldShowSkip: Bool {
        if case .scheduled(let next) = status {
            return Calendar.current.isDateInToday(next)
        }
        return false
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

    var body: some View {
        if mode == .oneTimeDate {
            Label(oneTimeLabel, systemImage: "calendar")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Text(day.minimalLabel)
                        .font(.caption2.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(weekdays.contains(day) ? theme.accentColor.opacity(0.22) : Color.clear, in: Circle())
                        .foregroundStyle(weekdays.contains(day) ? theme.accentColor : .secondary)
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
