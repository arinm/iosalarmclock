import SwiftUI
import SwiftData
import AlarmCore

/// Screen 2 — the home. Big "Next alarm" summary on top, premium cards below,
/// add button, empty state, and the skip-today confirmation banner.
struct AlarmListView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(BannerCenter.self) private var banners
    @Environment(ProFeatureManager.self) private var pro
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creatingNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add alarm")
                }
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
            ScrollView {
                LazyVStack(spacing: Theme.stackSpacing) {
                    if let banner = banners.current {
                        ActionBannerView(banner: banner)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    NextAlarmSummaryView(now: ctx.date)
                        .padding(.bottom, 4)

                    // Ungrouped alarms first, then each group with a bulk-action header.
                    ForEach(ungrouped) { alarm in
                        card(alarm, now: ctx.date)
                    }
                    ForEach(groupedNames, id: \.self) { name in
                        groupHeader(name)
                        ForEach(alarms.filter { $0.groupName == name }) { alarm in
                            card(alarm, now: ctx.date)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
                .animation(.snappy, value: banners.current?.id)
            }
        }
    }

    private var ungrouped: [AlarmItem] { alarms.filter { $0.groupName.isEmpty } }
    private var groupedNames: [String] {
        Array(Set(alarms.map(\.groupName).filter { !$0.isEmpty })).sorted()
    }

    private func card(_ alarm: AlarmItem, now: Date) -> some View {
        AlarmCardView(alarm: alarm, now: now)
            .onTapGesture { editing = alarm }
            .contextMenu { cardMenu(alarm) }
    }

    /// Group section header with bulk actions for every alarm in the group.
    @ViewBuilder
    private func groupHeader(_ name: String) -> some View {
        HStack {
            Text(name.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button { Task { await store.skipNextInGroup(name) } } label: { Label("Skip next (all)", systemImage: "forward.end") }
                Button { pausingGroup = GroupRef(name: name) } label: { Label("Pause all…", systemImage: "pause.circle") }
                Button { Task { await store.setEnabledGroup(name, false) } } label: { Label("Turn all off", systemImage: "bell.slash") }
                Button { Task { await store.setEnabledGroup(name, true) } } label: { Label("Turn all on", systemImage: "bell") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 16).padding(.horizontal, 6).padding(.bottom, 2)
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
        .task(id: banner.id) {
            try? await Task.sleep(for: .seconds(6))
            banners.dismiss(id: banner.id)
        }
    }

    private var icon: String {
        switch banner.kind {
        case .skip: "checkmark.circle.fill"
        case .disabled: "bell.slash.fill"
        case .enabled: "bell.fill"
        case .paused: "pause.circle.fill"
        case .neutral: "info.circle.fill"
        }
    }

    private var tint: Color {
        switch banner.kind {
        case .skip, .enabled: Theme.skipFg
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
