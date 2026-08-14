import SwiftUI
import AlarmCore

/// Screen 5 — defaults, permissions status, Pro, and honest reliability notes.
struct SettingsView: View {
    @Environment(PermissionManager.self) private var permissions
    @Environment(ProFeatureManager.self) private var pro
    @Environment(ThemeManager.self) private var theme
    @Environment(SoundManager.self) private var sounds
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultPreAlertMinutes") private var defaultPreAlert = 15
    @AppStorage("defaultSnoozeMinutes") private var defaultSnooze = 9
    /// Default sound (filename in Library/Sounds) seeded into NEW alarms —
    /// empty string = system default. Pro, like per-alarm sounds.
    @AppStorage("defaultSoundName") private var defaultSoundName = ""

    @State private var showPaywall = false
    @State private var appIcon = "default"
    @State private var showSoundPicker = false

    /// Longest default snooze this user may set. Free reaches 15 - parity with
    /// iOS 26's Clock, which caps its own custom snooze there - and Pro sells
    /// the range past it.
    ///
    /// While entitlements are UNRESOLVED the cap holds but can't drag an
    /// existing value down, so the cold-start window neither shaves a real Pro
    /// user's default nor lets a free user race StoreKit up to 60.
    private var snoozeCeiling: Int {
        if pro.isAvailable(.advancedSnooze) { return SnoozeSettings.maxDurationMinutes }
        return pro.entitlementsResolved
            ? SnoozeSettings.freeCeilingMinutes
            : max(SnoozeSettings.freeCeilingMinutes, defaultSnooze)
    }

    /// The default-snooze stepper, capped for the free tier on READ only.
    ///
    /// Deliberately NOT a `.task` that writes the clamped value back: this is
    /// `@AppStorage`, so clamping on disk would permanently destroy a lapsed
    /// Pro user's 45-minute default — it would still read 15 after they
    /// resubscribe. Same failure as the entitlement refresh that used to reset
    /// the Pro theme. Entitlement state may narrow what we SHOW; it must never
    /// overwrite what the user chose while they were entitled.
    private var cappedSnooze: Binding<Int> {
        Binding(get: { min($defaultSnooze.wrappedValue, snoozeCeiling) },
                set: { $defaultSnooze.wrappedValue = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if pro.isAvailable(.customPreAlertTiming) {
                        Stepper("Heads-up: \(defaultPreAlert) min", value: $defaultPreAlert, in: 1...120, step: 5)
                    } else {
                        ProLockRow(title: "Heads-up", value: "15 min") { showPaywall = true }
                    }
                    // Reads through a clamp instead of rewriting the stored
                    // value: see `cappedSnooze`.
                    Stepper("Snooze: \(cappedSnooze.wrappedValue) min",
                            value: cappedSnooze, in: 1...snoozeCeiling)
                    if snoozeCeiling < SnoozeSettings.maxDurationMinutes {
                        ProLockRow(title: "Longer snooze",
                                   value: "up to \(SnoozeSettings.maxDurationMinutes) min") { showPaywall = true }
                    }
                    if pro.isAvailable(.customSounds) {
                        // Opens the FULL sound picker (import, preview, delete) —
                        // an inline Picker can only choose, not import.
                        Button { showSoundPicker = true } label: {
                            HStack {
                                Text("Sound")
                                Spacer()
                                Text(defaultSoundName.isEmpty ? "Default" : sounds.displayName(defaultSoundName))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    } else {
                        ProLockRow(title: "Sound", value: "Default") { showPaywall = true }
                    }
                } header: {
                    Text("Defaults for new alarms")
                } footer: {
                    Text("New alarms start from these values - including the sound.")
                }

                Section("Permissions") {
                    permissionRow("Alarms (AlarmKit)", state: permissions.alarmKitState)
                    permissionRow("Heads-up notifications", state: permissions.notificationState)
                    if permissions.alarmKitState == .denied || permissions.notificationState == .denied,
                       let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open iOS Settings", destination: url)
                    }
                }

                Section("Appearance") {
                    if pro.isAvailable(.themes) {
                        Picker("Appearance", selection: Bindable(theme).appearance) {
                            ForEach(ThemeManager.Appearance.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        // Accent as a tappable swatch row (visual, not a dropdown).
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(ThemeManager.Accent.presets) { a in
                                    Button { theme.accent = a } label: {
                                        Circle()
                                            .fill(a.color)
                                            .frame(width: 30, height: 30)
                                            .overlay(Circle().strokeBorder(.primary.opacity(theme.accent == a ? 0.9 : 0), lineWidth: 2).padding(-3))
                                            .overlay(Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white).opacity(theme.accent == a ? 1 : 0))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(a.title)
                                }
                            }
                            .padding(.vertical, 6).padding(.horizontal, 8)
                        }
                        // Pick ANY color.
                        ColorPicker("Custom color", selection: Binding(
                            get: { theme.customColor },
                            set: { theme.customColor = $0 }   // also selects the custom accent
                        ), supportsOpacity: false)
                        if theme.accent == .custom {
                            Label("Using your custom color", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(theme.accentColor)
                        }
                    } else {
                        Button { showPaywall = true } label: {
                            HStack {
                                Label("Themes & app appearance", systemImage: "paintpalette")
                                Spacer(); ProPill()
                            }
                        }
                    }
                }

                Section("App icon") {
                    if pro.isAvailable(.appIcons) {
                        // Visual icon thumbnails (dark tile + accent mark, mirroring the real icon).
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AppIconOption.all) { option in
                                    Button { selectIcon(option.id) } label: {
                                        VStack(spacing: 4) {
                                            IconThumbnail(color: option.color, selected: appIcon == option.id)
                                            Text(option.title).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 6).padding(.horizontal, 8)
                        }
                    } else {
                        Button { showPaywall = true } label: {
                            HStack { Label("Alternate app icons", systemImage: "app.badge"); Spacer(); ProPill() }
                        }
                    }
                }

                Section("Punctual Pro") {
                    Button { showPaywall = true } label: {
                        Label(pro.isPro ? "You're on Pro" : "Upgrade to Pro", systemImage: "sparkles")
                    }
                }

                // Guideline 3.1.2(c) requires these inside the app. The paywall
                // carries them too; a reviewer who never opens the paywall
                // still has to be able to find them, and a user who already
                // bought has no reason to reopen it.
                Section("Legal") {
                    Link(destination: Legal.terms) {
                        Label("Terms of Use (EULA)", systemImage: "doc.text")
                    }
                    Link(destination: Legal.privacy) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: Legal.support) {
                        Label("Support & FAQ", systemImage: "questionmark.circle")
                    }
                }

                Section {
                    Text("Punctual uses Apple's AlarmKit for real alarms that ring through silent mode and Focus. Because skip-today and vacation pause are managed by the app, the next alarm is re-armed whenever you open Punctual. Open the app at least occasionally so far-future alarms stay armed.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Label("For anything you can't afford to miss, set a second alarm - ideally in another app or on another device.",
                          systemImage: "exclamationmark.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: {
                    Text("Reliability")
                } footer: {
                    Text("No alarm app can guarantee a ring: alarm delivery ultimately depends on iOS and your device's state, and a phone that's off, out of battery, or in a failed state can't ring at all. Punctual is provided without any warranty - please don't rely on it alone for critical wake-ups.")
                }
            }
            .punctualBackground()
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            // Bridge: SoundPickerView binds String? (nil = default), the stored
            // default is String ("" = default).
            .sheet(isPresented: $showSoundPicker) {
                SoundPickerView(soundName: Binding(
                    get: { defaultSoundName.isEmpty ? nil : defaultSoundName },
                    set: { defaultSoundName = $0 ?? "" }
                ))
            }
            .onAppear { appIcon = UIApplication.shared.alternateIconName ?? "default" }
        }
    }

    private func selectIcon(_ id: String) {
        appIcon = id // keep the user's choice highlighted (no confusing revert)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let name = id == "default" ? nil : id
        guard name != UIApplication.shared.alternateIconName else { return }
        UIApplication.shared.setAlternateIconName(name) { error in
            if let error { print("Alternate icon set failed: \(error.localizedDescription)") }
        }
    }

    private func permissionRow(_ title: String, state: PermissionManager.State) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch state {
            case .authorized: Label("On", systemImage: "checkmark.circle.fill").foregroundStyle(BrandColor.skip)
            case .denied: Label("Off", systemImage: "xmark.circle.fill").foregroundStyle(BrandColor.pause)
            case .notDetermined: Label("Not set", systemImage: "circle").foregroundStyle(.secondary)
            }
        }
        .labelStyle(.titleAndIcon).font(.subheadline)
    }
}

/// Alternate app-icon options. `id` is the asset name passed to
/// `setAlternateIconName` ("default" = the primary icon).
/// A dark tile + accent brand mark, mirroring the real alternate app icon.
struct IconThumbnail: View {
    let color: Color
    let selected: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.15, blue: 0.20),
                                          Color(red: 0.10, green: 0.11, blue: 0.16)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 56, height: 56)
            .overlay(BrandMark(size: 30, color: color))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? color : .clear, lineWidth: 3))
    }
}

struct AppIconOption: Identifiable {
    let id: String
    let title: String
    var color: Color {
        let name = id == "default" ? "peach" : id.replacingOccurrences(of: "AppIcon-", with: "").lowercased()
        return BrandColor.accent(named: name)
    }
    static let all: [AppIconOption] = [
        .init(id: "default", title: "Peach (default)"),
        .init(id: "AppIcon-Ocean", title: "Ocean"),
        .init(id: "AppIcon-Forest", title: "Forest"),
        .init(id: "AppIcon-Grape", title: "Grape"),
        .init(id: "AppIcon-Sunset", title: "Sunset"),
        .init(id: "AppIcon-Graphite", title: "Graphite"),
    ]
}
