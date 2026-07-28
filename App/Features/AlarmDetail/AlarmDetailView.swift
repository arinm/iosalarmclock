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
                pauseSection
                snoozeSection
                proSection
            }
            .punctualBackground()
            .navigationTitle(alarm.label.isEmpty ? "Alarm" : alarm.label)
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
                            let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current)
                            banners.show(.skip,
                                         title: "Skipped \(NotificationActionHandler.dayPhrase(day, calendar: .current)) - still active",
                                         subtitle: "Next alarm: \(next)",
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
            // Calendar-derived days off (read-only; managed by the calendar, not Undo-able here).
            if !alarm.autoSkippedDates.isEmpty {
                ForEach(alarm.autoSkippedDates.sorted(), id: \.self) { day in
                    Label("\(StatusPresenter.dayLabel(day)) · from calendar", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                }
            }
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
        Section("Snooze") {
            if alarm.snooze.isEnabled {
                LabeledContent("Duration", value: "\(alarm.snooze.durationMinutes) min")
            } else {
                Text("Off").foregroundStyle(.secondary)
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
