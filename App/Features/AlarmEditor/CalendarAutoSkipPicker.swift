import SwiftUI
import UIKit
import AlarmCore

/// Pro: which calendars mean "day off". The choice is shared by every alarm with
/// auto-skip on, and it shows live which days it would skip. A holidays calendar
/// full of observances (Valentine's Day, Tax Day) is then visible BEFORE it
/// costs anyone a wake-up, not after.
struct CalendarAutoSkipPicker: View {
    @Environment(AlarmStore.self) private var store

    @State private var calendars: [CalendarAutoSkip.Choice] = []
    @State private var selected: Set<String> = []
    @State private var preview: [DateOnly: [String]] = [:]
    @State private var authorized = true

    var body: some View {
        List {
            if !authorized {
                Section {
                    Text("Punctual can't read your calendars, so nothing is skipped.")
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Allow calendar access in Settings", destination: url)
                    }
                }
            } else if calendars.isEmpty {
                Section { Text("No calendars on this iPhone.").foregroundStyle(.secondary) }
            } else {
                Section {
                    Text("An all-day event in a calendar you tick skips your alarms that day. Tick only calendars that mean a day off - a holidays calendar, or one you keep for time off. Birthdays never count.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(sources, id: \.self) { source in
                    Section(source) {
                        ForEach(calendars.filter { $0.source == source }) { cal in
                            Button { toggle(cal.id) } label: { row(cal) }
                                .tint(.primary)
                        }
                    }
                }
                previewSection
            }
        }
        .punctualBackground()
        .navigationTitle("Days-off calendars")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var sources: [String] {
        var seen: [String] = []
        for c in calendars where !seen.contains(c.source) { seen.append(c.source) }
        return seen
    }

    private func row(_ cal: CalendarAutoSkip.Choice) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(cal.cgColor.map { Color(cgColor: $0) } ?? .secondary)
                .frame(width: 12, height: 12)
            Text(cal.title)
            Spacer()
            if selected.contains(cal.id) {
                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Theme.accent)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected.contains(cal.id) ? .isSelected : [])
    }

    private var previewSection: some View {
        Section {
            if selected.isEmpty {
                Text("Nothing is skipped until you tick a calendar.").foregroundStyle(.secondary)
            } else if preview.isEmpty {
                Text("No all-day events in the next 60 days.").foregroundStyle(.secondary)
            } else {
                ForEach(preview.keys.sorted(), id: \.self) { day in
                    HStack(alignment: .firstTextBaseline) {
                        Text(StatusPresenter.dayLabel(day)).monospacedDigit()
                        Spacer()
                        Text(preview[day].flatMap { ListText.joined($0).nilIfEmpty } ?? String(localized: "All-day event", bundle: AppLanguage.bundle))
                            .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                    }
                }
            }
        } header: {
            Text("Days off in the next 60 days")
        } footer: {
            Text("Holiday calendars can include days that aren't days off, like Valentine's Day or Tax Day. The evening before a day off you get one quiet notice, with Ring anyway.")
        }
    }

    private func load() async {
        authorized = store.calendarAutoSkip.isAuthorized
        guard authorized else { return }
        calendars = store.calendarAutoSkip.availableCalendars()
        // From the saved choice, not `autoSkipCalendarIDs` (as of the last
        // refresh): a chosen calendar that synced since must show ticked, or the
        // next tap would drop it. Ones not listed stay chosen (`offered`).
        selected = store.calendarAutoSkip.selectedCalendarIDs.intersection(calendars.map(\.id))
        preview = await store.calendarAutoSkip.preview(ids: selected, calendar: .current)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        let ids = selected
        // Saved now, not after the preview's await: with rapid taps, an earlier
        // tap's task could otherwise finish last and save the older choice.
        store.selectAutoSkipCalendars(ids, offered: Set(calendars.map(\.id)))
        Task {
            let days = await store.calendarAutoSkip.preview(ids: ids, calendar: .current)
            if ids == selected { preview = days }
            await store.refreshAllSchedules()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
