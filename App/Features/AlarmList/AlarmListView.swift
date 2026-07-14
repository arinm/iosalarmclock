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
    @Query(sort: [SortDescriptor(\AlarmItem.hour), SortDescriptor(\AlarmItem.minute)])
    private var alarms: [AlarmItem]

    @State private var editing: AlarmItem?
    @State private var detail: AlarmItem?
    @State private var pausing: AlarmItem?
    @State private var pausingGroup: GroupRef?
    @State private var creatingNew = false
    @State private var showSettings = false
    @State private var showPaywall = false

    /// Single skip entry point so every surface shows the same confirm+undo banner
    /// with the *actual* skipped day named (not always "today").
    private func skip(_ alarm: AlarmItem) async {
        guard let day = await store.skipNextOccurrence(alarm) else { return }
        let next = NotificationActionHandler.describe(alarm.nextOccurrence, calendar: .current)
        banners.show(.skip,
                     title: "Skipped \(NotificationActionHandler.dayPhrase(day, calendar: .current)) — still active",
                     subtitle: "Next alarm: \(next)",
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
            .punctualBackground()
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            // Reachable bottom + (the redesign's signature).
            .overlay(alignment: .bottom) {
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

    private var content: some View {
        // TimelineView keeps every "Rings in …" label live without manual timers.
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let now = ctx.date
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.stackSpacing) {
                        permissionBanner
                        NextAlarmSummaryView(now: now)
                            .padding(.bottom, 4)

                        // All alarms as identical full cards (default order). A
                        // confirmation renders inline ABOVE its card (reads as a
                        // toast about the card below it).
                        ForEach(alarms) { alarm in
                            VStack(spacing: Theme.stackSpacing) {
                                if let banner = banners.current, banner.alarmID == alarm.id {
                                    ActionBannerView(banner: banner)
                                        // Subtle pop-in: scale from 92% + slide, fade out on dismiss.
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.92, anchor: .top)
                                                .combined(with: .move(edge: .top))
                                                .combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                                AlarmCardView(alarm: alarm, now: now)
                                    .onTapGesture { editing = alarm }
                                    .contextMenu { cardMenu(alarm) }
                            }
                            .id(alarm.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120) // clear the floating + and its shadow
                    .animation(.snappy, value: banners.current?.id)
                }
                // A new alarm sorts by time and can land OFF-SCREEN — scroll its
                // card (and the banner above it) into view so the confirmation
                // is never announced to nobody.
                .onChange(of: banners.current?.id) { _, _ in
                    guard let target = banners.current?.alarmID else { return }
                    withAnimation(.snappy) { proxy.scrollTo(target, anchor: .center) }
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
        if permissions.hasResolved && permissions.alarmKitState == .denied {
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
        .padding(.bottom, 28)
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

/// One calm, reusable confirmation banner for every state change (skip, disable,
/// enable, pause). Always reassuring, always with Undo when reversible — so the
/// less-reversible "disable" is never quieter than "skip today".
struct ActionBannerView: View {
    let banner: BannerCenter.Banner
    @Environment(BannerCenter.self) private var banners
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
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
                                         title: "Paused “\(groupName)” until \(PauseRangeSheet.dateFmt.string(from: e))",
                                         subtitle: "Every alarm in the group — then resumes automatically",
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
