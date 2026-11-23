import WidgetKit
import SwiftUI
import SwiftData
import AlarmCore

/// Home/Lock Screen widget: the next alarm with its live countdown, the day it
/// rings, the repeat days, and the pre-alert — "rich context" so the medium
/// widget stays informative even when the alarm isn't today.
struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let info: Info?
    struct Info {
        let timeText: String
        let label: String
        let fireDate: Date
        let weekdays: [Weekday]   // empty for a one-time alarm
        let isOneTime: Bool
        let preAlertMinutes: Int? // nil when pre-alert is off
    }
}

struct NextAlarmProvider: AppIntentTimelineProvider {
    typealias Entry = NextAlarmEntry
    typealias Intent = SelectAlarmIntent

    func placeholder(in context: Context) -> NextAlarmEntry {
        NextAlarmEntry(date: .now, info: .init(
            timeText: "08:00", label: "Work", fireDate: .now.addingTimeInterval(3600),
            weekdays: Array(Weekday.weekdays), isOneTime: false, preAlertMinutes: 15))
    }

    func snapshot(for configuration: SelectAlarmIntent, in context: Context) async -> NextAlarmEntry {
        await makeEntries(selected: configuration.alarm?.id, limit: 1).entries[0]
    }

    func timeline(for configuration: SelectAlarmIntent, in context: Context) async -> Timeline<NextAlarmEntry> {
        let (entries, end) = await makeEntries(selected: configuration.alarm?.id)
        // Within the hour anyway: nothing reloads on a time-zone or 12/24-hour
        // change, and the entries keep showing until the new ones come.
        return Timeline(entries: entries, policy: .after(min(end, .now.addingTimeInterval(3600))))
    }

    /// One entry each time the words change: the countdown (each minute, each
    /// hour while a day or more out), the day at midnight, and the alarm after
    /// the one that rings. The widget redraws only at entries; reloads alone
    /// are budgeted by iOS. `end` is the first change not covered.
    @MainActor
    private func makeEntries(selected: UUID?, limit: Int = 240) -> (entries: [NextAlarmEntry], end: Date) {
        let calc = NextOccurrenceCalculator()
        let cal = Calendar.current
        let context = ModelContext(SharedModelContainer.make())
        let alarms = (try? context.fetch(FetchDescriptor<AlarmItem>())) ?? []

        func next(after date: Date) -> (AlarmItem, Date)? {
            if let selected, let item = alarms.first(where: { $0.id == selected }),
               let fire = calc.nextOccurrence(for: item.schedule, after: date, calendar: cal) {
                // A specific alarm was pinned in the widget configuration.
                return (item, fire)
            }
            // Default: soonest upcoming across all alarms.
            return alarms
                .compactMap { item in calc.nextOccurrence(for: item.schedule, after: date, calendar: cal).map { (item, $0) } }
                .min { $0.1 < $1.1 }
        }

        var entries: [NextAlarmEntry] = []
        var date = Date.now
        let horizon = date.addingTimeInterval(24 * 3600)
        while entries.count < limit, date < horizon {
            guard let (item, fire) = next(after: date) else {
                entries.append(NextAlarmEntry(date: date, info: nil))
                return (entries, horizon)
            }
            entries.append(NextAlarmEntry(date: date, info: .init(
                timeText: TimeText.string(fire),
                label: item.label,
                fireDate: fire,
                weekdays: Weekday.allCases.filter { item.repeatWeekdays.contains($0) },
                isOneTime: item.mode == .oneTimeDate,
                preAlertMinutes: item.preAlert.isEnabled ? item.preAlert.minutesBefore : nil
            )))
            let left = fire.timeIntervalSince(date)
            let step: TimeInterval = left > 86_400 ? 3600 : 60
            let tick = fire.addingTimeInterval(-step * (left / step).rounded(.down))
            let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date)) ?? horizon
            // The countdown floors ("12h 29m" at 10:00:00.5 for 22:30), so it
            // changes just after a tick: start the entry a second past it.
            date = min(tick, midnight).addingTimeInterval(1)
        }
        return (entries, date)
    }
}

// MARK: - Views

struct NextAlarmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NextAlarmEntry

    var body: some View {
        Group {
            if let info = entry.info {
                switch family {
                case .systemMedium: MediumView(info: info, now: entry.date)
                case .accessoryRectangular: AccessoryView(info: info, now: entry.date)
                default: SmallView(info: info, now: entry.date)
                }
            } else {
                EmptyWidgetView()
            }
        }
        // Words and dates follow a language picked in the app (see AppLanguage).
        .environment(\.locale, AppLanguage.locale)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    /// "Today" / "Tomorrow" / "Mon, Jun 24", as of the entry's date: an entry
    /// past midnight is drawn ahead of time.
    static func dayText(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        switch cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day {
        case 0: return String(localized: "Today", bundle: AppLanguage.bundle)
        case 1: return String(localized: "Tomorrow", bundle: AppLanguage.bundle)
        default: return DayText.short(date)
        }
    }
}

/// "10:30" with a smaller "PM", before the time where the language puts it
/// first ("午後10:30"), as on the app's hero card: at one size a 12-hour time
/// with a two-digit hour doesn't fit the small widget.
private struct TimeView: View {
    let date: Date
    let size: CGFloat

    var body: some View {
        let parts = TimeText.parts(date)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if let period = parts.period, parts.periodFirst { periodText(period) }
            Text(parts.time).font(.system(size: size, weight: .semibold, design: .rounded)).monospacedDigit()
            if let period = parts.period, !parts.periodFirst { periodText(period) }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    private func periodText(_ period: String) -> some View {
        Text(period).font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
    }
}

private struct MediumView: View {
    let info: NextAlarmEntry.Info
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEXT ALARM").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TimeView(date: info.fireDate, size: 38)
                if !info.label.isEmpty {
                    Text(info.label).font(.headline).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Text(verbatim: "\(CountdownText.ringsIn(info.fireDate, from: now)) · \(NextAlarmWidgetView.dayText(info.fireDate, now: now))")
                .font(.caption.weight(.medium)).foregroundStyle(BrandColor.currentAccent()).lineLimit(1)

            Spacer(minLength: 0)

            HStack {
                if info.isOneTime {
                    Label(NextAlarmWidgetView.dayText(info.fireDate, now: now), systemImage: "calendar")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    WeekdayPillRow(selected: info.weekdays)
                }
                Spacer()
                if let m = info.preAlertMinutes {
                    Label("\(m)m before", systemImage: "bell.badge")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SmallView: View {
    let info: NextAlarmEntry.Info
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label gives context ("Work"); falls back to the eyebrow.
            Text(info.label.isEmpty ? String(localized: "NEXT ALARM", bundle: AppLanguage.bundle) : info.label.uppercased())
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            TimeView(date: info.fireDate, size: 30)
            // Two lines: "鳴るまであと11時間4分" or "Sonne dans 11 h 43 min" doesn't fit one.
            Text(CountdownText.ringsIn(info.fireDate, from: now))
                .font(.caption.weight(.medium)).foregroundStyle(BrandColor.currentAccent()).lineLimit(2)
            Spacer(minLength: 0)
            // Repeat days (or the date for a one-time) — info the countdown lacks.
            if info.isOneTime {
                Label(NextAlarmWidgetView.dayText(info.fireDate, now: now), systemImage: "calendar")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            } else {
                WeekdayPillRow(selected: info.weekdays, pill: 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// One line each for the time, the label and the countdown: side by side,
/// "Schlafenszeit" and "Klingelt in 10 h 55 min" were cut in most languages.
private struct AccessoryView: View {
    let info: NextAlarmEntry.Info
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "alarm.fill")
                Text(info.timeText).fontWeight(.semibold)
            }
            if !info.label.isEmpty { Text(info.label).foregroundStyle(.secondary) }
            // The sentence where it fits, else a timer and "10 h 55 min";
            // that one may shrink for "menos de un minuto".
            ViewThatFits(in: .horizontal) {
                Text(CountdownText.ringsIn(info.fireDate, from: now))
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(CountdownText.string(until: info.fireDate, from: now))
                }
                .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetAccentable()
    }
}

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT ALARM").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text("No alarms").font(.headline)
            Text("Open Punctual to add one").font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Compact Mon–Sun pills mirroring the in-app card.
private struct WeekdayPillRow: View {
    let selected: [Weekday]
    var pill: CGFloat = 18
    private let ordered: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        // Empty set == every day (mirrors the in-app card): light all pills.
        let effective = selected.isEmpty ? ordered : selected
        HStack(spacing: pill < 18 ? 3 : 4) {
            ForEach(ordered, id: \.self) { day in
                let on = effective.contains(day)
                Text(day.minimalLabel)
                    .font(.system(size: pill * 0.55, weight: .bold))
                    .frame(width: pill, height: pill)
                    .background(on ? BrandColor.currentAccent().opacity(0.25) : Color.clear, in: Circle())
                    .foregroundStyle(on ? BrandColor.currentAccent() : .secondary)
            }
        }
    }
}

struct NextAlarmWidget: Widget {
    let kind = "NextAlarmWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectAlarmIntent.self, provider: NextAlarmProvider()) { entry in
            NextAlarmWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Alarm")
        .description("Your next alarm (or a chosen one) with the live countdown, day, and repeat days.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
