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
        await makeEntry(selected: configuration.alarm?.id)
    }

    func timeline(for configuration: SelectAlarmIntent, in context: Context) async -> Timeline<NextAlarmEntry> {
        let entry = await makeEntry(selected: configuration.alarm?.id)
        return Timeline(entries: [entry], policy: .after(Date.now.addingTimeInterval(15 * 60)))
    }

    @MainActor
    private func makeEntry(selected: UUID?) -> NextAlarmEntry {
        let calc = NextOccurrenceCalculator()
        let context = ModelContext(SharedModelContainer.make())
        let alarms = (try? context.fetch(FetchDescriptor<AlarmItem>())) ?? []

        let chosen: (AlarmItem, Date)?
        if let selected, let item = alarms.first(where: { $0.id == selected }),
           let next = calc.nextOccurrence(for: item.schedule, after: .now, calendar: .current) {
            // A specific alarm was pinned in the widget configuration.
            chosen = (item, next)
        } else {
            // Default: soonest upcoming across all alarms.
            chosen = alarms
                .compactMap { item -> (AlarmItem, Date)? in
                    guard let next = calc.nextOccurrence(for: item.schedule, after: .now, calendar: .current) else { return nil }
                    return (item, next)
                }
                .min { $0.1 < $1.1 }
        }

        guard let (item, fire) = chosen else { return NextAlarmEntry(date: .now, info: nil) }
        let f = DateFormatter(); f.timeStyle = .short
        return NextAlarmEntry(date: .now, info: .init(
            timeText: f.string(from: fire),
            label: item.label,
            fireDate: fire,
            weekdays: Weekday.allCases.filter { item.repeatWeekdays.contains($0) },
            isOneTime: item.mode == .oneTimeDate,
            preAlertMinutes: item.preAlert.isEnabled ? item.preAlert.minutesBefore : nil
        ))
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
        .containerBackground(.fill.tertiary, for: .widget)
    }

    /// "Today" / "Tomorrow" / "Mon 24 Jun".
    static func dayText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }
}

private struct MediumView: View {
    let info: NextAlarmEntry.Info
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEXT ALARM").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(info.timeText)
                    .font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit()
                if !info.label.isEmpty {
                    Text(info.label).font(.headline).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Text("\(CountdownFormatter.ringsIn(info.fireDate, from: now)) · \(NextAlarmWidgetView.dayText(info.fireDate))")
                .font(.caption.weight(.medium)).foregroundStyle(BrandColor.currentAccent()).lineLimit(1)

            Spacer(minLength: 0)

            HStack {
                if info.isOneTime {
                    Label(NextAlarmWidgetView.dayText(info.fireDate), systemImage: "calendar")
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
            Text(info.label.isEmpty ? "NEXT ALARM" : info.label.uppercased())
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            Text(info.timeText)
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(CountdownFormatter.ringsIn(info.fireDate, from: now))
                .font(.caption.weight(.medium)).foregroundStyle(BrandColor.currentAccent()).lineLimit(1)
            Spacer(minLength: 0)
            // Repeat days (or the date for a one-time) — info the countdown lacks.
            if info.isOneTime {
                Label(NextAlarmWidgetView.dayText(info.fireDate), systemImage: "calendar")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            } else {
                WeekdayPillRow(selected: info.weekdays, pill: 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AccessoryView: View {
    let info: NextAlarmEntry.Info
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "alarm.fill")
                Text(info.timeText).fontWeight(.semibold)
                if !info.label.isEmpty { Text("· \(info.label)").foregroundStyle(.secondary).lineLimit(1) }
            }
            Text(CountdownFormatter.ringsIn(info.fireDate, from: now)).foregroundStyle(.secondary)
        }
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
