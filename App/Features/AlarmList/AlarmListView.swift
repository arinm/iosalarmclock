import SwiftUI
import SwiftData
import AlarmCore

/// Screen 2 — the home. Big "Next alarm" summary on top, premium cards below,
/// add button, empty state, and the skip-today confirmation banner.
struct AlarmListView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(BannerCenter.self) private var banners
    @Environment(ProFeatureManager.self) private var pro
    @Environment(ThemeManager.self) private var theme
    @Environment(PermissionManager.self) private var permissions
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Query(sort: [SortDescriptor(\AlarmItem.hour), SortDescriptor(\AlarmItem.minute)])
    private var alarms: [AlarmItem]

    @State private var editing: AlarmItem?
    @State private var detail: AlarmItem?
    @State private var pausing: AlarmItem?
    @State private var pausingGroup: GroupRef?
    @State private var creatingNew = false
    @State private var showSettings = false
    @State private var showPaywall = false
    /// Bumped after scrolling to the "Are you up?" card from its notice.
    @State private var wakeCheckFocus = 0

    /// Single skip entry point so every surface shows the same confirm+undo banner
    /// with the *actual* skipped day named (not always "today").
    private func skip(_ alarm: AlarmItem) async {
        guard let day = await store.skipNextOccurrence(alarm) else { return }
        let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current, context: .middleOfSentence)
        banners.show(.skip,
                     title: NotificationActionHandler.skippedTitle(day),
                     subtitle: String(localized: "Next alarm: \(next)", bundle: AppLanguage.bundle),
                     alarmID: alarm.id,
                     undo: { [store] in await store.unskip(alarm, day: day) })
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    var body: some View {
        NavigationStack {
            Group {
                if alarms.isEmpty {
                    VStack(spacing: Theme.stackSpacing) {
                        permissionBanner
                        EmptyAlarmsView { creatingNew = true }
                    }
                    .padding(.horizontal)
                } else {
                    content
                }
            }
            // Rebuilt on a language pick (Settings): words made with
            // String(localized:) don't follow `\.locale` on their own.
            .id(locale.identifier)
            .punctualBackground()
            // Only ASKS. The counting lives in AlarmStore.refreshAllSchedules,
            // which runs on every foreground and observer event — a SwiftUI
            // `.task(id:)` would miss the common case of returning to an app
            // still in memory, and would undercount mornings.
            //
            // Asking stays here: `requestReview` needs a live view, and the home
            // screen is where someone lands after being woken. Fires on first
            // appear and on every return to foreground, so a user who has earned
            // it gets asked at the next natural moment.
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--open-settings") { showSettings = true }
                #endif
                AppReviewPrompt.askIfEarned(requestReview)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { AppReviewPrompt.askIfEarned(requestReview) }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            // Reachable bottom + (the redesign's signature). safeAreaInset (not
            // an overlay) so the List automatically keeps its end clear of the
            // button — at max scroll the last card's Skip button sits fully
            // above the +, instead of being covered by it.
            .safeAreaInset(edge: .bottom) {
                if !alarms.isEmpty { addButton }
            }
            .sheet(isPresented: $creatingNew) {
                AlarmEditorView(mode: .create)
            }
            .sheet(item: $editing) { item in
                AlarmEditorView(mode: .edit(item))
            }
            .sheet(item: $detail) { item in
                AlarmDetailView(alarm: item)
            }
            .sheet(item: $pausing) { item in
                PauseRangeSheet(alarm: item)
            }
            .sheet(item: $pausingGroup) { ref in
                GroupPauseSheet(groupName: ref.name)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private static let wakeCheckRowID = "wakeCheck"

    private var content: some View {
        // TimelineView keeps every "Rings in …" label live without manual timers.
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let now = ctx.date
            ScrollViewReader { proxy in
                // List (plain, chrome hidden) instead of ScrollView: native
                // swipe actions on the cards — the muscle memory from Clock.
                List {
                    Group {
                        permissionBanner
                        // "Are you up?" waiting for an answer: the in-app way to
                        // say I'm up, even with notifications off.
                        if let check = store.wakeCheck, check.fireDate > now {
                            WakeCheckCard(ringsAt: check.fireDate, focus: wakeCheckFocus)
                                .id(Self.wakeCheckRowID)
                        }
                        NextAlarmSummaryView(now: now)
                            .padding(.bottom, 4)
                    }
                    .listRowStyleClear()

                    // All alarms as identical full cards (default order). A
                    // confirmation renders inline ABOVE its card (reads as a
                    // toast about the card below it).
                    ForEach(alarms) { alarm in
                        VStack(spacing: Theme.stackSpacing) {
                            if let banner = banners.current, banner.alarmID == alarm.id {
                                ActionBannerView(banner: banner)
                                    // Bubble pop-in: scale up from 70% with a spring
                                    // overshoot (below) so the confirmation grabs the
                                    // eye instead of quietly sliding in; gentle
                                    // scale-down + fade on dismiss.
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.7, anchor: .center)
                                            .combined(with: .opacity),
                                        removal: .scale(scale: 0.9, anchor: .center)
                                            .combined(with: .opacity)
                                    ))
                            }
                            AlarmCardView(alarm: alarm, now: now)
                                .onTapGesture { editing = alarm }
                                .contextMenu { cardMenu(alarm) }
                                // VoiceOver: one element per card, actionable —
                                // not a stream of letters with no way to edit.
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint("Edits this alarm")
                                // Deterministic default activation (double-tap):
                                // combine+isButton alone taps the element CENTER,
                                // which can land on an inner control.
                                .accessibilityAction { editing = alarm }
                                .accessibilityAction(named: alarm.isEnabled ? "Turn off" : "Turn on") {
                                    Task {
                                        await store.setEnabled(alarm, !alarm.isEnabled)
                                        UIAccessibility.post(notification: .announcement,
                                                             argument: alarm.isEnabled ? String(localized: "Alarm on", bundle: AppLanguage.bundle) : String(localized: "Alarm off", bundle: AppLanguage.bundle))
                                    }
                                }
                                .accessibilityAction(named: "Details") { detail = alarm }
                                // Card-level (NOT row-level — container actions
                                // would leak onto the banner's Undo button):
                                .modifier(SkipNextA11y(alarm: alarm, skip: { a in Task { await skip(a) } }))
                                .modifier(StopSnoozeA11y(alarm: alarm))
                        }
                        .id(alarm.id)
                        .listRowStyleClear()
                        // Leading skip swipe — recurring + enabled only (see
                        // SkipAffordances for the reasoning per state).
                        .modifier(SkipAffordances(alarm: alarm, skip: { a in Task { await skip(a) } }))
                        // Trailing swipe: delete — two-step (no full swipe), since
                        // delete has no undo.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await store.delete(alarm) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }

                    // Shown on the real count: only when some heads-ups really
                    // didn't fit under iOS's cap this pass and the first is
                    // near. With notifications off there are none to wait for.
                    if let waitFrom = store.headsUpsWaitFrom, permissions.canPreAlert {
                        HeadsUpBudgetNote(waitFrom: waitFrom)
                            .listRowStyleClear()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // Springy overshoot drives the banner's bubble pop-in (see transition).
                .animation(.spring(response: 0.38, dampingFraction: 0.6), value: banners.current?.id)
                // A new alarm sorts by time and can land OFF-SCREEN — scroll its
                // card (and the banner above it) into view so the confirmation
                // is never announced to nobody.
                .onChange(of: banners.current?.id) { _, _ in
                    guard let target = banners.current?.alarmID else { return }
                    withAnimation(.snappy) { proxy.scrollTo(target, anchor: .center) }
                }
                // A tap on the "Are you up?" notice: scroll up to its card, only
                // when the card is there. `initial` also covers a cold launch,
                // where the tap lands before the list exists. Not `task(id:)`:
                // clearing the flag would cancel that task mid-wait.
                .onChange(of: store.wakeCheckFocusPending, initial: true) { _, pending in
                    guard pending else { return }
                    store.wakeCheckFocusPending = false
                    guard let check = store.wakeCheck, check.fireDate > .now else { return }
                    Task {
                        // Let the list lay out first, or scrollTo does nothing.
                        try? await Task.sleep(for: .milliseconds(350))
                        // Centered, not .top: the card is the first row, so the
                        // list stops at its very top, large title kept.
                        withAnimation(.snappy) { proxy.scrollTo(Self.wakeCheckRowID, anchor: .center) }
                        wakeCheckFocus += 1
                        WakeCheck.log.notice("Notice tapped: scrolled to the card")
                    }
                }
            }
        }
    }

    /// Persistent warning when AlarmKit permission is denied — otherwise alarms
    /// silently never ring, the worst possible failure for an alarm app. Only
    /// shown once permissions are resolved and actually denied (notDetermined is
    /// handled by onboarding).
    @ViewBuilder
    private var permissionBanner: some View {
        if !ProcessInfo.processInfo.arguments.contains("--app-store-screenshots"),
           permissions.hasResolved && permissions.alarmKitState == .denied {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alarms can't ring").font(.subheadline.weight(.semibold))
                        Text("Alarm access is off. Tap to turn it on in Settings.")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .strokeBorder(.orange.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Settings to enable alarm permission")
        }
    }

    private var addButton: some View {
        Button { creatingNew = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(theme.accentColor, in: Circle())
                .shadow(color: theme.accentColor.opacity(0.5), radius: 18, y: 4)
        }
        .accessibilityLabel("Add alarm")
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func cardMenu(_ alarm: AlarmItem) -> some View {
        Button { editing = alarm } label: { Label("Edit", systemImage: "pencil") }
        Button { detail = alarm } label: { Label("Details", systemImage: "info.circle") }
        Button {
            if pro.isAvailable(.vacationPause) { pausing = alarm } else { showPaywall = true }
        } label: { Label(pro.isAvailable(.vacationPause) ? "Pause…" : "Pause… (Pro)", systemImage: "pause.circle") }
        Button { Task { await skip(alarm) } } label: { Label("Skip next", systemImage: "forward.end") }
        Button { Task { await store.duplicate(alarm) } } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        if !alarm.groupName.isEmpty {
            Menu("Group: \(alarm.groupName)") {
                Button { Task { await store.skipNextInGroup(alarm.groupName) } } label: { Label("Skip next (all)", systemImage: "forward.end") }
                Button { pausingGroup = GroupRef(name: alarm.groupName) } label: { Label("Pause all…", systemImage: "pause.circle") }
                Button { Task { await store.setEnabledGroup(alarm.groupName, false) } } label: { Label("Turn all off", systemImage: "bell.slash") }
                Button { Task { await store.setEnabledGroup(alarm.groupName, true) } } label: { Label("Turn all on", systemImage: "bell") }
            }
        }
        Divider()
        Button(role: .destructive) { Task { await store.delete(alarm) } } label: { Label("Delete", systemImage: "trash") }
    }
}

/// Why some heads-ups aren't set yet: iOS holds 64 pending notifications per
/// app, and an install with many alarms wants more. Calm on purpose: nothing
/// is wrong with the alarms, and opening the app (which the user is doing)
/// is what adds the rest.
private struct HeadsUpBudgetNote: View {
    let waitFrom: Date

    private var day: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(waitFrom) || calendar.isDateInTomorrow(waitFrom) { return DayText.phrase(waitFrom) }
        return DayText.short(waitFrom)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge")
                .foregroundStyle(.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Some heads-ups wait for your next visit").font(.subheadline.weight(.semibold))
                Text("iPhone holds up to 64 scheduled notifications per app, and your alarms need more. Heads-ups from \(day) onward are added when you open Punctual. The alarms themselves aren't affected.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .padding(.top, 4)
    }
}

/// "Are you up?" (Pro) after a Stop: the check rings again unless the user
/// answers. The same answer as the notice's I'm up button. It stands out from
/// the alarm cards (accent fill, a slowly breathing accent border) since a
/// missed answer means another ring.
private struct WakeCheckCard: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ringsAt: Date
    /// Bumped when the list scrolls here from the notice: the icon bounces.
    let focus: Int
    @State private var breathe = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sun.horizon.fill")
                .foregroundStyle(Theme.accent)
                .font(.title2)
                .symbolEffect(.bounce, options: .nonRepeating, value: focus)
            VStack(alignment: .leading, spacing: 4) {
                Text("Are you up?").font(.headline)
                Text(ringsAgain)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("I'm up") { Task { await store.endWakeCheck() } }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: shape)
        .background(Theme.accent.opacity(0.14), in: shape)
        .overlay(
            shape.strokeBorder(Theme.accent.opacity(reduceMotion ? 0.8 : (breathe ? 0.95 : 0.3)),
                               lineWidth: 2)
        )
        .onAppear {
            guard !reduceMotion, !breathe else { return } // don't stack animations on re-appear
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .padding(.bottom, 4)
    }

    private var ringsAgain: String {
        let time = TimeText.string(ringsAt)
        return TimeText.isHourOne(ringsAt)
            ? String(localized: "The alarm rings again at \(time). (hour 1)", bundle: AppLanguage.bundle)
            : String(localized: "The alarm rings again at \(time).", bundle: AppLanguage.bundle)
    }
}

/// One calm, reusable confirmation banner for every state change (skip, disable,
/// enable, pause). Always reassuring, always with Undo when reversible — so the
/// less-reversible "disable" is never quieter than "skip today".
struct ActionBannerView: View {
    let banner: BannerCenter.Banner
    @Environment(BannerCenter.self) private var banners
    @Environment(ThemeManager.self) private var theme
    /// Flipped on appear to fire the icon's one-shot bounce in sync with the
    /// banner's pop-in, so the eye lands on the confirmation.
    @State private var popped = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
                .symbolEffect(.bounce, options: .nonRepeating, value: popped)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).font(.subheadline.weight(.semibold))
                if let subtitle = banner.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let undo = banner.undo {
                Button("Undo") {
                    Task { await undo(); banners.dismiss(id: banner.id) }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(16)
        .background(
            // Material base + a wash of the banner's tint so confirmations pop
            // against a wall of cards instead of reading as one more grey row.
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
        // Fire the icon bounce as the banner pops in. Keyed on the banner id too:
        // SwiftUI can reuse this view instance for a NEW banner, in which case
        // `onAppear` never runs again and the bounce would silently stop happening.
        .onAppear { popped.toggle() }
        .onChange(of: banner.id) { _, _ in popped.toggle() }
    }

    private var icon: String {
        switch banner.kind {
        case .skip: "checkmark.circle.fill"
        case .disabled: "bell.slash.fill"
        case .paused: "pause.circle.fill"
        case .neutral: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch banner.kind {
        case .skip: Theme.skipFg
        case .disabled: .secondary
        // Confirmations ("Alarm set", "Snooze stopped") wear the user's accent.
        case .neutral: theme.accentColor
        case .paused: Theme.pauseFg
        }
    }
}

/// Leading skip swipe — recurring AND enabled alarms only. One-time: skipping
/// disarms it forever while the banner claims "still active". Disabled:
/// skipNextOccurrence returns nil (schedule disabled) and the swipe would be a
/// silent no-op — no effect, no feedback. Paused alarms keep the swipe: skip
/// then targets the first occurrence AFTER the pause, a legitimate action.
private struct SkipAffordances: ViewModifier {
    let alarm: AlarmItem
    let skip: (AlarmItem) -> Void

    func body(content: Content) -> some View {
        if alarm.mode != .oneTimeDate, alarm.isEnabled {
            content
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button { skip(alarm) } label: {
                        Label("Skip", systemImage: "forward.end.fill")
                    }
                    .tint(Theme.skipFg)
                }
        } else {
            content
        }
    }
}

/// VoiceOver "Skip next" — applied to the CARD element (not the row VStack):
/// container-level custom actions propagate onto every contained element, so a
/// row-level action would also pollute the inline banner's Undo button.
/// Same gating as the swipe above.
private struct SkipNextA11y: ViewModifier {
    let alarm: AlarmItem
    let skip: (AlarmItem) -> Void

    func body(content: Content) -> some View {
        if alarm.mode != .oneTimeDate, alarm.isEnabled {
            content.accessibilityAction(named: "Skip next") { skip(alarm) }
        } else {
            content
        }
    }
}

/// Exposes "Stop snooze" to VoiceOver while a snooze runs — the combined card
/// element swallows the inline button. Card-level for the same propagation
/// reason as SkipNextA11y.
private struct StopSnoozeA11y: ViewModifier {
    let alarm: AlarmItem
    @Environment(AlarmStore.self) private var store

    func body(content: Content) -> some View {
        if store.snoozingItemIDs.contains(alarm.id), alarm.isEnabled {
            content.accessibilityAction(named: "Stop snooze") {
                Task {
                    await store.stopSnooze(alarm)
                    // Honest either way: recurring → "tomorrow at 6:30";
                    // one-time → "No further alarms" (never claim "still active").
                    let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current, context: .middleOfSentence)
                    UIAccessibility.post(notification: .announcement,
                                         argument: String(localized: "Snooze stopped. Next alarm: \(next)", bundle: AppLanguage.bundle))
                }
            }
        } else {
            content
        }
    }
}

private extension View {
    /// Strip List's row chrome so rows render as our free-floating cards:
    /// no separators, no default background, card-friendly insets.
    func listRowStyleClear() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: Theme.stackSpacing / 2, leading: 16,
                                      bottom: Theme.stackSpacing / 2, trailing: 16))
    }
}

/// Identifiable wrapper so a group name can drive a `.sheet(item:)`.
struct GroupRef: Identifiable { let id = UUID(); let name: String }

/// Bulk pause for every alarm in a group.
struct GroupPauseSheet: View {
    let groupName: String
    @Environment(AlarmStore.self) private var store
    @Environment(BannerCenter.self) private var banners
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date = .now
    @State private var end: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $start, displayedComponents: .date)
                    DatePicker("Until", selection: $end, in: start..., displayedComponents: .date)
                } footer: {
                    Text("Pauses every alarm in “\(groupName)” for this range.")
                }
            }
            .navigationTitle("Pause \(groupName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pause") {
                        let range = DateRange(
                            start: DateOnly(date: start, calendar: .current),
                            end: DateOnly(date: end, calendar: .current)
                        )
                        let e = end
                        let anchor = store.alarms(inGroup: groupName).first?.id
                        Task {
                            await store.pauseGroup(groupName, range: range)
                            banners.show(.paused,
                                         title: String(localized: "Paused “\(groupName)” until \(PauseRangeSheet.dateFmt.string(from: e))", bundle: AppLanguage.bundle),
                                         subtitle: String(localized: "Every alarm in the group - then resumes automatically", bundle: AppLanguage.bundle),
                                         alarmID: anchor,
                                         undo: { [store] in await store.unpauseGroup(groupName, range: range) })
                        }
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
        }
    }
}

struct EmptyAlarmsView: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            BrandMark(size: 64)
            Text("No alarms yet").font(.title2.weight(.semibold))
            Text("Add one and see exactly when it'll ring.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(action: onAdd) {
                Label("Add alarm", systemImage: "plus")
                    .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
    }
}
