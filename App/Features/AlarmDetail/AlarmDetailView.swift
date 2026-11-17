import SwiftUI
import AlarmCore

/// Screen 4 — advanced per-alarm management: skipped days, pause ranges, snooze,
/// and Pro affordances. Reachable from the card's context menu.
struct AlarmDetailView: View {
    @Bindable var alarm: AlarmItem
    @Environment(AlarmStore.self) private var store
    @Environment(ProFeatureManager.self) private var pro
    @Environment(BannerCenter.self) private var banners
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var pausing = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                headerSection
                skipSection
                if alarm.autoSkipOnCalendarEvents { calendarSection }
                pauseSection
                snoozeSection
                proSection
            }
            .punctualBackground()
            .navigationTitle(alarm.label.isEmpty ? String(localized: "Alarm", bundle: AppLanguage.bundle) : alarm.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } }
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $editing) { AlarmEditorView(mode: .edit(alarm)) }
            // No global banner from here — the pause appears instantly as a row
            // in `pauseSection` below (with "Clear all pauses" as the undo).
            .sheet(isPresented: $pausing) { PauseRangeSheet(alarm: alarm, showsBanner: false) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var headerSection: some View {
        Section {
            let presented = StatusPresenter.line(alarm.status())
            VStack(alignment: .leading, spacing: 8) {
                Text(presented.text).font(.headline).foregroundStyle(presented.fg)
                if case .scheduled(let next) = alarm.status(), Calendar.current.isDateInToday(next) {
                    Button {
                        Task {
                            guard let day = await store.skipNextOccurrence(alarm) else { return }
                            let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current, context: .middleOfSentence)
                            banners.show(.skip,
                                         title: NotificationActionHandler.skippedTitle(day),
                                         subtitle: String(localized: "Next alarm: \(next)", bundle: AppLanguage.bundle),
                                         alarmID: alarm.id,
                                         undo: { [store] in await store.unskip(alarm, day: day) })
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            dismiss()
                        }
                    } label: {
                        Label("Skip today", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.skipFg)
                }
            }
        }
    }

    private var skipSection: some View {
        Section("Skipped days") {
            if alarm.skippedOccurrenceDates.isEmpty {
                Text("None").foregroundStyle(.secondary)
            } else {
                ForEach(alarm.skippedOccurrenceDates.sorted(), id: \.self) { day in
                    HStack {
                        Label(StatusPresenter.dayLabel(day), systemImage: "forward.end")
                        Spacer()
                        Button(role: .destructive) { Task { await store.unskip(alarm, day: day) } } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    /// Rings the calendar takes away in the next 60 days, each with Ring anyway,
    /// plus the days the user already chose to ring (with a way back).
    @ViewBuilder
    private var calendarSection: some View {
        let cal = Calendar.current
        let now = Date.now
        let today = DateOnly(date: now, calendar: cal)
        let until = cal.date(byAdding: .day, value: 60, to: now) ?? now
        let skipped = CalendarSkipPlanner.suppressedOccurrences(
            schedule: alarm.scheduleIgnoringCalendar, calendarSkips: Set(alarm.autoSkippedDates),
            after: now, until: until, calendar: cal)
        let ringing = CalendarSkipPlanner.suppressedOccurrences(
            schedule: alarm.scheduleIgnoringCalendar,
            calendarSkips: Set(alarm.calendarSkipOverrides.filter { $0 >= today && store.calendarDayTitles[$0] != nil }),
            after: now, until: until, calendar: cal)
        Section {
            // A real skip is never hidden: the days stay listed, with Ring anyway,
            // even if the calendars behind them are gone until the next refresh.
            if store.autoSkipCalendarIDs.isEmpty && skipped.isEmpty && ringing.isEmpty {
                NavigationLink { CalendarAutoSkipPicker() } label: {
                    Label("Choose your days-off calendars", systemImage: "calendar.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            } else {
                if skipped.isEmpty && ringing.isEmpty {
                    Text("No skipped alarms in the next 60 days.").foregroundStyle(.secondary)
                }
                ForEach(skipped, id: \.self) { ring in
                    let day = DateOnly(date: ring, calendar: cal)
                    HStack {
                        calendarDayLabel(day, note: reasons(day))
                        Spacer()
                        Button("Ring anyway") { Task { await store.ringAnyway(alarm, day: day) } }
                            .buttonStyle(.bordered).font(.subheadline)
                    }
                }
                ForEach(ringing, id: \.self) { ring in
                    let day = DateOnly(date: ring, calendar: cal)
                    HStack {
                        calendarDayLabel(day, note: String(localized: "Rings anyway · \(reasons(day))", bundle: AppLanguage.bundle))
                        Spacer()
                        Button("Skip") { Task { await store.skipForCalendarAgain(alarm, day: day) } }
                            .buttonStyle(.bordered).font(.subheadline)
                    }
                }
                NavigationLink("Days-off calendars") { CalendarAutoSkipPicker() }
            }
        } header: {
            Text("Calendar days off")
        }
    }

    private func reasons(_ day: DateOnly) -> String {
        let titles = store.calendarDayTitles[day] ?? []
        return titles.isEmpty ? String(localized: "All-day event", bundle: AppLanguage.bundle) : ListText.joined(titles)
    }

    private func calendarDayLabel(_ day: DateOnly, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(StatusPresenter.dayLabel(day), systemImage: "calendar")
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var pauseSection: some View {
        Section("Pauses") {
            ForEach(Array(alarm.pausedDateRanges.enumerated()), id: \.offset) { _, range in
                Label("\(StatusPresenter.dayLabel(range.start)) → \(StatusPresenter.dayLabel(range.end))",
                      systemImage: "pause.circle")
            }
            Button {
                if pro.isAvailable(.vacationPause) { pausing = true } else { showPaywall = true }
            } label: {
                HStack {
                    Label("Add pause", systemImage: "plus")
                    if !pro.isAvailable(.vacationPause) { Spacer(); ProPill() }
                }
            }
            if !alarm.pausedDateRanges.isEmpty {
                Button(role: .destructive) { Task { await store.clearPauses(alarm) } } label: {
                    Label("Clear all pauses", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var snoozeSection: some View {
        // Not "Snooze": that key is the ringing button, fr "Répéter", which reads as "Repeat" here.
        Section("Snooze settings") {
            if alarm.snooze.isEnabled {
                LabeledContent("Duration") { Text("\(alarm.snooze.durationMinutes) min") }
            } else {
                Text("Off").foregroundStyle(.secondary)
            }
            if alarm.wakeCheckEnabled {
                LabeledContent("Are you up?") { Text("On") }
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        if !pro.isPro {
            Section {
                Button { showPaywall = true } label: {
                    Label("Unlock Pro - pause, themes, groups & more", systemImage: "sparkles")
                }
            }
        }
    }
}
