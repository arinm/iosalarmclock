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
                    EmptyAlarmsView { creatingNew = true }
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
            ScrollView {
                LazyVStack(spacing: Theme.stackSpacing) {
                    NextAlarmSummaryView(now: now)
                        .padding(.bottom, 4)

                    // All alarms as identical full cards (default order). A
                    // skip/disable confirmation renders INLINE under its card.
                    ForEach(alarms) { alarm in
                        VStack(spacing: Theme.stackSpacing) {
                            AlarmCardView(alarm: alarm, now: now)
                                .onTapGesture { editing = alarm }
                                .contextMenu { cardMenu(alarm) }
                            if let banner = banners.current, banner.alarmID == alarm.id {
                                ActionBannerView(banner: banner)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 120) // clear the floating + and its shadow
                .animation(.snappy, value: banners.current?.id)
            }
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
    }

    private var icon: String {
        switch banner.kind {
        case .skip: "checkmark.circle.fill"
        case .disabled: "bell.slash.fill"
        case .paused: "pause.circle.fill"
        case .neutral: "info.circle.fill"
        }
    }

    private var tint: Color {
        switch banner.kind {
        case .skip: Theme.skipFg
        case .disabled, .neutral: .secondary
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
                        Task { await store.pauseGroup(groupName, range: range) }
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
