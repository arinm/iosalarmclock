import SwiftUI
import AlarmCore

/// Screen 3 — create/edit. Time picker with a *live* "Rings in Xh Ym" label, the
/// thing Apple Clock never shows. Repeat days, one-time date, label, pre-alert,
/// snooze, sound, and access to pause. Faster and clearer than Clock.
struct AlarmEditorView: View {
    enum Mode { case create, edit(AlarmItem) }

    @Environment(AlarmStore.self) private var store
    @Environment(ProFeatureManager.self) private var pro
    @Environment(PermissionManager.self) private var permissions
    @Environment(BannerCenter.self) private var banners
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    // Draft state
    @State private var time: Date
    @State private var label: String
    @State private var alarmMode: AlarmMode
    @State private var weekdays: Set<Weekday>
    @State private var oneTimeDate: Date
    @State private var snooze: SnoozeSettings
    @State private var preAlert: PreAlertSettings
    @State private var vibration: Bool
    @State private var groupName: String
    @State private var autoSkipCalendar: Bool
    @State private var soundName: String?
    @State private var showSoundPicker = false
    @State private var preAlertMessage: String
    @State private var additionalPreAlerts: Set<Int>
    @State private var showPause = false
    @State private var showPaywall = false

    /// Preset extra pre-alert lead times offered as toggle chips.
    private let extraOffsetChoices = [5, 10, 30, 60]

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            // Seed new alarms from the user's Settings defaults.
            let d = UserDefaults.standard
            let preAlertMin = d.object(forKey: "defaultPreAlertMinutes") as? Int ?? 15
            let snoozeMin = d.object(forKey: "defaultSnoozeMinutes") as? Int ?? 9
            let snoozeCount = d.object(forKey: "defaultSnoozeCount") as? Int ?? 3
            _time = State(initialValue: Self.defaultTime())
            _label = State(initialValue: "")
            _alarmMode = State(initialValue: .recurring)
            _weekdays = State(initialValue: Weekday.weekdays)
            _oneTimeDate = State(initialValue: .now)
            _snooze = State(initialValue: SnoozeSettings(durationMinutes: snoozeMin, maxCount: snoozeCount))
            _preAlert = State(initialValue: PreAlertSettings(minutesBefore: preAlertMin))
            _vibration = State(initialValue: true)
            _groupName = State(initialValue: "")
            _autoSkipCalendar = State(initialValue: false)
            // Default sound from Settings (Pro); empty string = system default.
            let defaultSound = d.string(forKey: "defaultSoundName") ?? ""
            _soundName = State(initialValue: defaultSound.isEmpty ? nil : defaultSound)
            _preAlertMessage = State(initialValue: "")
            _additionalPreAlerts = State(initialValue: [])
        case .edit(let item):
            var comps = DateComponents(); comps.hour = item.hour; comps.minute = item.minute
            _time = State(initialValue: Calendar.current.date(from: comps) ?? .now)
            _label = State(initialValue: item.label)
            _alarmMode = State(initialValue: item.mode)
            _weekdays = State(initialValue: item.repeatWeekdays)
            _oneTimeDate = State(initialValue: item.oneTimeDate?.startOfDay(in: .current) ?? .now)
            _snooze = State(initialValue: item.snooze)
            _preAlert = State(initialValue: item.preAlert)
            _vibration = State(initialValue: item.vibrationEnabled)
            _groupName = State(initialValue: item.groupName)
            _autoSkipCalendar = State(initialValue: item.autoSkipOnCalendarEvents)
            _soundName = State(initialValue: item.soundName)
            _preAlertMessage = State(initialValue: item.preAlertMessage)
            _additionalPreAlerts = State(initialValue: Set(item.additionalPreAlertMinutes))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                timeSection
                repeatSection
                Section("Label") {
                    TextField("Alarm name", text: $label)
                    if pro.isAvailable(.alarmGroups) {
                        TextField("Group (optional)", text: $groupName)
                            .autocorrectionDisabled()
                    } else {
                        ProLockRow(title: "Group", value: "") { showPaywall = true }
                    }
                }
                preAlertSection
                snoozeSection
                Section {
                    if pro.isAvailable(.customSounds) {
                        Button { showSoundPicker = true } label: {
                            HStack {
                                Label("Sound", systemImage: "speaker.wave.2")
                                Spacer()
                                Text(soundDisplay).foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    } else {
                        ProLockRow(title: "Sound", value: "Default") { showPaywall = true }
                    }
                } footer: {
                    Text("Used for the heads-up notification and the alarm ring.")
                }

                Section {
                    if pro.isAvailable(.calendarAwareSkip) {
                        Toggle("Auto-skip on calendar days off", isOn: $autoSkipCalendar)
                            .onChange(of: autoSkipCalendar) { _, on in
                                if on {
                                    Task {
                                        let granted = await store.calendarAutoSkip.requestAccess()
                                        if !granted { autoSkipCalendar = false } // revert; no silent no-op
                                    }
                                }
                            }
                    } else {
                        ProLockRow(title: "Auto-skip on holidays", value: "") { showPaywall = true }
                    }
                } header: {
                    Text("Smart skip")
                } footer: {
                    Text("Skips automatically on days that have an all-day event in your calendar (holidays, vacation, OOO).")
                }
                if case .edit(let item) = mode {
                    Section {
                        Button {
                            if pro.isAvailable(.vacationPause) { showPause = true } else { showPaywall = true }
                        } label: {
                            HStack {
                                Label("Pause for a date range", systemImage: "pause.circle")
                                if !pro.isAvailable(.vacationPause) {
                                    Spacer()
                                    ProPill()
                                }
                            }
                        }
                        // Live feedback: a pause added via the sheet above shows
                        // up here immediately (the item is the live model).
                        ForEach(Array(item.pausedDateRanges.enumerated()), id: \.offset) { _, range in
                            Label("Paused \(StatusPresenter.dayLabel(range.start)) → \(StatusPresenter.dayLabel(range.end))",
                                  systemImage: "pause.circle")
                                .foregroundStyle(.secondary)
                        }
                        if !item.pausedDateRanges.isEmpty {
                            Button(role: .destructive) { Task { await store.clearPauses(item) } } label: {
                                Label("Clear pauses", systemImage: "xmark.circle")
                            }
                        }
                        Button(role: .destructive) {
                            Task { await store.delete(item) }
                            dismiss()
                        } label: {
                            Label("Delete alarm", systemImage: "trash")
                        }
                    }
                }
            }
            .punctualBackground()
            .navigationTitle(isEditing ? "Edit Alarm" : "New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showPause) {
                // No global banner — the pause appears instantly as a row in the
                // section below (with "Clear pauses" as the undo).
                if case .edit(let item) = mode { PauseRangeSheet(alarm: item, showsBanner: false) }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showSoundPicker) { SoundPickerView(soundName: $soundName) }
        }
    }

    // MARK: Sections

    private var timeSection: some View {
        Section {
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            // Live countdown — the signature feature.
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                Text(CountdownFormatter.ringsIn(previewFireDate(now: ctx.date), from: ctx.date))
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var repeatSection: some View {
        Section("Repeat") {
            Picker("Mode", selection: $alarmMode) {
                Text("Weekly").tag(AlarmMode.recurring)
                Text("Once on a date").tag(AlarmMode.oneTimeDate)
            }
            .pickerStyle(.segmented)

            if alarmMode == .recurring {
                RepeatDayPicker(selection: $weekdays)
                if weekdays.isEmpty {
                    Label("No days selected — rings every day at \(timeOnlyString).",
                          systemImage: "repeat")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(weekdays.humanSummary).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                DatePicker("Date", selection: $oneTimeDate, in: Date.now..., displayedComponents: .date)
            }
        }
    }

    private var preAlertSection: some View {
        Section {
            Toggle("Heads-up", isOn: $preAlert.isEnabled)
            if preAlert.isEnabled {
                if permissions.hasResolved && permissions.notificationState == .denied {
                    Label("Notifications are off — the heads-up won't show. The alarm still rings.",
                          systemImage: "bell.badge.slash")
                        .font(.caption).foregroundStyle(.orange)
                }
                if pro.isPro {
                    Stepper("\(preAlert.minutesBefore) min before",
                            value: $preAlert.minutesBefore, in: 1...120, step: 5)

                    // Multiple pre-alerts: extra lead-time chips.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Also alert me").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(extraOffsetChoices, id: \.self) { m in
                                let on = additionalPreAlerts.contains(m)
                                Button {
                                    if on { additionalPreAlerts.remove(m) } else { additionalPreAlerts.insert(m) }
                                } label: {
                                    Text("\(m)m").font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(on ? Theme.accentSoft : Theme.neutralSoft, in: Capsule())
                                        .foregroundStyle(on ? Theme.accent : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("Custom message (optional)", text: $preAlertMessage)
                } else {
                    // Free: fixed 15-min heads-up. One single Pro entry (not 3 stacked locks).
                    ProLockRow(title: "Custom timing, multiple & message", value: "15 min") { showPaywall = true }
                }
            }
        } header: {
            Text("Heads-up")
        } footer: {
            Text(pro.isPro
                 ? "A friendly notification before the alarm rings, with a Skip today button. The alarm still rings on its own."
                 : "Free alarms get a 15-minute heads-up with a Skip today button. Custom & multiple heads-ups are part of Pro.")
        }
    }

    private var snoozeSection: some View {
        Section("Snooze") {
            Toggle("Snooze enabled", isOn: $snooze.isEnabled)
            if snooze.isEnabled {
                if pro.isAvailable(.advancedSnooze) {
                    Stepper("Duration: \(snooze.durationMinutes) min",
                            value: $snooze.durationMinutes, in: 1...60)
                } else {
                    // Free: basic snooze at the default; a custom duration is Pro.
                    ProLockRow(title: "Snooze duration", value: "9 min") { showPaywall = true }
                }
            }
        }
    }

    // MARK: Logic

    private var isEditing: Bool { if case .edit = mode { return true }; return false }

    private func components() -> (h: Int, m: Int) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (c.hour ?? 7, c.minute ?? 0)
    }

    private var soundDisplay: String {
        guard let soundName else { return "Default" }
        return (soundName as NSString).deletingPathExtension
    }

    private var timeOnlyString: String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: time)
    }

    private func previewFireDate(now: Date) -> Date {
        let (h, m) = components()
        var draft = AlarmSchedule(hour: h, minute: m, mode: alarmMode, repeatWeekdays: weekdays)
        if alarmMode == .oneTimeDate {
            draft.oneTimeDate = DateOnly(date: oneTimeDate, calendar: .current)
        }
        return NextOccurrenceCalculator().nextOccurrence(for: draft, after: now, calendar: .current)
            ?? now.addingTimeInterval(60)
    }

    private func save() {
        let (h, m) = components()
        let oneTime = alarmMode == .oneTimeDate ? DateOnly(date: oneTimeDate, calendar: .current) : nil

        // Enforce free-tier defaults so gating can't be bypassed — BUT only once
        // entitlements are known, so a Pro user editing during the cold-start
        // window isn't silently downgraded. `strip(_:)` keeps the draft value
        // unless we're sure the user isn't entitled.
        func strip(_ feature: ProFeatureManager.Feature) -> Bool {
            pro.entitlementsResolved && !pro.isAvailable(feature)
        }
        let finalPreAlert = strip(.customPreAlertTiming)
            ? PreAlertSettings(isEnabled: preAlert.isEnabled, minutesBefore: 15) : preAlert
        let finalSnooze = strip(.advancedSnooze)
            ? SnoozeSettings(isEnabled: snooze.isEnabled, durationMinutes: 9, maxCount: 3) : snooze
        let finalMessage = strip(.preAlertMessages) ? "" : preAlertMessage
        let finalExtra = strip(.multiplePreAlerts) ? [] : Array(additionalPreAlerts).sorted()
        let finalGroup = strip(.alarmGroups) ? "" : groupName.trimmingCharacters(in: .whitespaces)
        let finalAutoSkip = !strip(.calendarAwareSkip) && autoSkipCalendar
        let finalSound = strip(.customSounds) ? nil : soundName

        // Safety net for the notifications permission: onboarding step 2 is the
        // primary ask, but if the app died between steps the state stays
        // .notDetermined FOREVER (nothing else ever asks) and the heads-up
        // silently never fires. Saving an alarm with the heads-up ON is the
        // natural, explained moment to recover.
        func ensureHeadsUpPermission(_ enabled: Bool) async {
            if enabled, permissions.notificationState == .notDetermined {
                await permissions.requestNotifications()
            }
        }

        // Confirmation banner ("Alarm set — rings in 7h 59m") shown inline under
        // the card once the editor sheet dismisses. Reads the engine-computed
        // nextOccurrence AFTER the store reschedules, so the countdown is truth.
        func confirm(_ item: AlarmItem, verb: String, snoozeStopped: Bool = false) {
            guard item.isEnabled, let next = item.nextOccurrence else { return }
            let when = NotificationActionHandler.describe(next, calendar: .current)
            banners.show(.neutral,
                         title: "\(verb) — rings in \(CountdownFormatter.string(until: next, from: .now))",
                         // Tell the user the running snooze was stopped by this edit.
                         subtitle: snoozeStopped ? "Snooze stopped · \(when)" : when,
                         alarmID: item.id)
        }

        switch mode {
        case .create:
            let item = AlarmItem(
                hour: h, minute: m, label: label, mode: alarmMode,
                repeatWeekdays: weekdays, oneTimeDate: oneTime,
                vibrationEnabled: vibration, snooze: finalSnooze, preAlert: finalPreAlert
            )
            item.preAlertMessage = finalMessage
            item.additionalPreAlertMinutes = finalExtra
            item.groupName = finalGroup
            item.autoSkipOnCalendarEvents = finalAutoSkip
            item.soundName = finalSound
            Task {
                await store.create(item)
                await ensureHeadsUpPermission(finalPreAlert.isEnabled)
                confirm(item, verb: "Alarm set")
            }
        case .edit(let item):
            Task {
                let snoozeStopped = await store.update(item) {
                    $0.hour = h; $0.minute = m; $0.label = label
                    $0.mode = alarmMode; $0.repeatWeekdays = weekdays; $0.oneTimeDate = oneTime
                    $0.vibrationEnabled = vibration; $0.snooze = finalSnooze; $0.preAlert = finalPreAlert
                    $0.preAlertMessage = finalMessage; $0.additionalPreAlertMinutes = finalExtra
                    $0.groupName = finalGroup
                    $0.autoSkipOnCalendarEvents = finalAutoSkip
                    $0.soundName = finalSound
                }
                await ensureHeadsUpPermission(finalPreAlert.isEnabled)
                confirm(item, verb: "Saved", snoozeStopped: snoozeStopped)
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private static func defaultTime() -> Date {
        var comps = DateComponents(); comps.hour = 7; comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }
}

struct ProBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            Text("\(text) · Pro").font(.caption2.weight(.semibold))
        }
        .foregroundStyle(Theme.accent)
    }
}

/// The small "🔒 PRO" capsule used to mark gated controls.
struct ProPill: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
            Text("PRO")
        }
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Theme.accentSoft, in: Capsule())
        .foregroundStyle(Theme.accent)
    }
}

/// A locked settings row: shows the free value and a tappable "PRO" pill that
/// opens the paywall — the contextual upgrade trigger at the moment of intent.
struct ProLockRow: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                Text(value).foregroundStyle(.secondary)
                ProPill()
            }
        }
        .buttonStyle(.plain)
    }
}
