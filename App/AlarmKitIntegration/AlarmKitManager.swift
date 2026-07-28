import Foundation
import OSLog
import AlarmCore
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import ActivityKit   // AlertConfiguration.AlertSound (AlarmKit alarm sound type)
#endif

/// Diagnostics — view in Console.app or Xcode's console (subsystem
/// "com.punctual.app", category "AlarmKit"). Helps confirm alarms are actually
/// scheduled, especially when validating firing on a real device.
private let alarmLog = Logger(subsystem: "com.punctual.app", category: "AlarmKit")

/// Abstraction over AlarmKit so the scheduler is testable and so the app still
/// builds if compiled without the framework. The live implementation is
/// `AlarmKitManager`. Main-actor isolated because it touches `AlarmItem`
/// (a SwiftData @Model, which is main-actor bound).
@MainActor
protocol AlarmKitManaging {
    func requestAuthorization() async -> Bool
    func authorizationState() async -> AlarmAuthState
    /// Arm one concrete AlarmKit alarm per supplied fire date for this item.
    /// Returns the dates that were ACTUALLY armed (a `schedule()` throw — e.g.
    /// authorization denied — drops its date), so callers never persist an
    /// occurrence the system doesn't hold.
    @discardableResult
    func scheduleOccurrences(_ dates: [Date], for item: AlarmItem) async -> [Date]
    /// Cancel the AlarmKit alarms previously armed for these exact fire dates.
    /// Ids are derived deterministically from (item.id, date), so this works
    /// across processes (widget/Siri) and across app launches.
    /// Returns the dates VERIFIED to be gone from the system afterwards (empty
    /// when the live list couldn't be read), so callers know whether it is safe
    /// to forget their cancel handle for an occurrence.
    @discardableResult
    func cancelOccurrences(_ dates: [Date], for item: AlarmItem) async -> [Date]
    /// The ids of every alarm the system holds for this app right now, or `nil`
    /// when the truth can't be read. Lets the scheduler verify persisted state
    /// against reality instead of trusting it.
    func liveAlarmIDs() -> Set<UUID>?
    /// ONE snapshot of the system's alarms split into (all ids, active subset),
    /// where "active" = any alarm NOT in `.scheduled` state (counting down,
    /// snoozing, paused, or alerting right now). Both sets come from a single
    /// read so `active ⊆ all` always holds and they share fate — the orphan
    /// sweep relies on the active set as the sole protection for an alarm
    /// ringing/snoozing whose occurrence has left the tracked dates. Fails
    /// CLOSED (`nil`) when unreadable, so the sweep purges nothing on a bad read.
    func alarmSnapshot() -> (all: Set<UUID>, active: Set<UUID>)?
    /// Cancel arbitrary alarm ids directly (orphan purge). Unlike
    /// `cancelOccurrences`, these ids aren't derived from an item — the sweep
    /// passes system-held ids it has already proven belong to no tracked
    /// occurrence. Cancelling an unknown/stopped id is a harmless no-op.
    func cancelRawIDs(_ ids: Set<UUID>) async
}

enum AlarmAuthState: Sendable { case notDetermined, authorized, denied }

/// Metadata we attach to every AlarmKit alarm so the Live Activity / Lock Screen
/// presentation can show the label and our app can correlate fired alarms back
/// to the owning `AlarmItem`.
#if canImport(AlarmKit)
struct PunctualMetadata: AlarmMetadata {
    let alarmItemID: UUID
    let label: String
    let occurrence: Date

    /// TOLERANT DECODE — load-bearing now that a widget actually decodes this.
    /// Alarms live in the AlarmKit daemon for days, so a build that ADDS a field
    /// here would otherwise fail to decode the metadata of alarms scheduled by
    /// the PREVIOUS build, and the system may then drop those alarms — silently
    /// recreating the very "it didn't ring" failure this file exists to prevent.
    /// Every field must therefore stay optional-with-fallback; add new ones the
    /// same way (`decodeIfPresent` + default), never as a hard requirement.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alarmItemID = try c.decodeIfPresent(UUID.self, forKey: .alarmItemID) ?? UUID()
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        occurrence = try c.decodeIfPresent(Date.self, forKey: .occurrence) ?? .distantPast
    }

    init(alarmItemID: UUID, label: String, occurrence: Date) {
        self.alarmItemID = alarmItemID
        self.label = label
        self.occurrence = occurrence
    }
}
#endif

/// Live AlarmKit integration.
///
/// IMPORTANT: AlarmKit's exact symbol surface evolves across the iOS 26 betas.
/// The structure below follows the documented WWDC25 shape (AlarmManager,
/// Alarm.Schedule.fixed, AlarmConfiguration, AlarmPresentation, secondary
/// "countdown" button for custom snooze). If a symbol name differs in your SDK,
/// adjust *only* inside this file — nothing else in the app depends on AlarmKit.
@MainActor
final class AlarmKitManager: AlarmKitManaging {

    /// Deterministic UUID for a given (item, occurrence). MUST be a pure function
    /// of its inputs — no `Hasher` (its seed is randomised per process, so it is
    /// neither cross-process nor cross-launch stable). We take the item's 16
    /// UUID bytes and fold the occurrence's epoch seconds (big-endian) into the
    /// low 8 bytes, giving a stable, collision-resistant id per occurrence.
    nonisolated static func occurrenceID(item id: UUID, date: Date) -> UUID {
        var bytes = withUnsafeBytes(of: id.uuid) { Array($0) }          // 16 bytes
        let epoch = Int64(date.timeIntervalSince1970.rounded()).bigEndian
        let epochBytes = withUnsafeBytes(of: epoch) { Array($0) }       // 8 bytes
        for i in 0..<8 { bytes[8 + i] ^= epochBytes[i] }
        let t = (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],
                 bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15])
        return UUID(uuid: t)
    }

    private func occurrenceID(item: AlarmItem, date: Date) -> UUID {
        Self.occurrenceID(item: item.id, date: date)
    }

    /// Observe AlarmKit state changes (an alarm fired, was stopped, snoozed, or
    /// cancelled) and re-arm our look-ahead window in response, so a fired
    /// one-shot is promptly replaced while the app is alive. This complements the
    /// foreground re-arm and the pre-armed window; it is best-effort (only runs
    /// while the process lives). Never throws — a missing/renamed symbol is caught
    /// at compile time inside this file only.
    /// Tracks the single live subscription so repeated `.task` runs (scene
    /// reconnects, multi-scene) can't stack duplicate infinite observers.
    private var observerTask: Task<Void, Never>?

    /// `onChange` receives the authoritative set of alarm ids the system currently
    /// holds, so the scheduler can detect externally-cancelled occurrences (present
    /// in our persisted state but missing here) and re-arm them.
    ///
    /// The emitted stream element is used only as a WAKE signal — the id set is
    /// re-read at processing time (`liveAlarmIDs()`), because our own multi-step
    /// writes emit mid-write snapshots that would spuriously look like drift. A
    /// short debounce also gives a sibling process (widget skip intent) time to
    /// finish its own cancel→save→re-arm sequence before we reconcile.
    func observeAlarmUpdates(_ onChange: @escaping @MainActor (Set<UUID>) async -> Void) {
        guard observerTask == nil else { return }
        #if canImport(AlarmKit)
        observerTask = Task { @MainActor in
            for await _ in AlarmManager.shared.alarmUpdates {
                try? await Task.sleep(for: .seconds(1)) // settle: skip mid-write snapshots
                guard let liveIDs = liveAlarmIDs() else { continue }
                alarmLog.notice("AlarmKit update — \(liveIDs.count, privacy: .public) alarm(s) live; reconciling window")
                await onChange(liveIDs)
            }
        }
        #endif
    }

    func requestAuthorization() async -> Bool {
        #if canImport(AlarmKit)
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            alarmLog.notice("Authorization requested → \(String(describing: state), privacy: .public)")
            return state == .authorized
        } catch {
            alarmLog.error("Authorization error: \(error.localizedDescription, privacy: .public)")
            return false
        }
        #else
        alarmLog.notice("AlarmKit unavailable in this SDK")
        return false
        #endif
    }

    func authorizationState() async -> AlarmAuthState {
        #if canImport(AlarmKit)
        switch AlarmManager.shared.authorizationState {
        case .authorized: return .authorized
        case .denied: return .denied
        default: return .notDetermined
        }
        #else
        return .notDetermined
        #endif
    }

    @discardableResult
    func scheduleOccurrences(_ dates: [Date], for item: AlarmItem) async -> [Date] {
        let name = item.label.isEmpty ? "Alarm" : item.label
        #if canImport(AlarmKit)
        let auth = AlarmManager.shared.authorizationState
        if auth != .authorized {
            alarmLog.error("Not scheduling '\(name, privacy: .public)' — authorization is \(String(describing: auth), privacy: .public)")
        }
        var armed: [Date] = []
        for date in dates {
            let id = occurrenceID(item: item, date: date)
            do {
                let config = makeConfiguration(for: item, occurrence: date)
                try await AlarmManager.shared.schedule(id: id, configuration: config)
                armed.append(date)
                alarmLog.notice("Scheduled '\(name, privacy: .public)' id \(id, privacy: .public) @ \(date, privacy: .public)")
            } catch {
                // The alarm ceiling is dynamic (Apple: "no set number") and is
                // reported as a real error — call it out by name so a user who
                // hits it produces a diagnosable log instead of a silent no-ring.
                if case AlarmManager.AlarmError.maximumLimitReached = error {
                    alarmLog.fault("Schedule FAILED '\(name, privacy: .public)' @ \(date, privacy: .public): ALARM LIMIT REACHED — the system refused to hold more alarms")
                } else {
                    alarmLog.error("Schedule FAILED '\(name, privacy: .public)' @ \(date, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // Cross-check against the system, but REPORT ONLY — never drop.
        // Absence from `AlarmManager.alarms` immediately after `schedule()` is
        // ambiguous: it can mean "not scheduled" or "the daemon list hasn't
        // propagated yet". Dropping on that ambiguity would remove our cancel
        // handle for an alarm the system may really hold, and the occurrence
        // would then fall out of the orphan sweep's legitimate set and be purged
        // — our own safety net deleting the user's real alarm. A throw from
        // `schedule` is the only proof of failure, and that already drops above.
        if !armed.isEmpty, let live = liveAlarmIDs() {
            let missing = armed.filter { !live.contains(occurrenceID(item: item, date: $0)) }
            if !missing.isEmpty {
                alarmLog.fault("Arm VERIFICATION for '\(name, privacy: .public)': \(missing.count, privacy: .public) occurrence(s) not (yet) visible in AlarmManager.alarms — keeping them tracked: \(missing, privacy: .public)")
            }
        }
        return armed
        #else
        alarmLog.notice("[AlarmKit unavailable] would schedule \(dates.count) alarm(s)")
        return []
        #endif
    }

    /// Authoritative read of what the system holds right now. `nil` when the
    /// list can't be read (no AlarmKit, or the query throws).
    func liveAlarmIDs() -> Set<UUID>? {
        #if canImport(AlarmKit)
        guard let alarms = try? AlarmManager.shared.alarms else { return nil }
        return Set(alarms.map(\.id))
        #else
        return nil
        #endif
    }

    /// One read of the system's alarms → (all ids, active subset). "Active" is
    /// any alarm NOT in `.scheduled` state (alerting/countdown/paused). Deriving
    /// both from a SINGLE read guarantees `active ⊆ all` and gives them shared
    /// fate: the orphan sweep must never lose the active set (its only guard for
    /// a live ring) while keeping the all set. Fails CLOSED (`nil`) on a bad read.
    func alarmSnapshot() -> (all: Set<UUID>, active: Set<UUID>)? {
        #if canImport(AlarmKit)
        guard let alarms = try? AlarmManager.shared.alarms else { return nil }
        let all = Set(alarms.map(\.id))
        let active = Set(alarms.filter { $0.state != .scheduled }.map(\.id))
        return (all, active)
        #else
        return nil
        #endif
    }

    func cancelRawIDs(_ ids: Set<UUID>) async {
        #if canImport(AlarmKit)
        var purged = 0
        for id in ids {
            do { try AlarmManager.shared.cancel(id: id); purged += 1 }
            catch {
                alarmLog.error("Purge FAILED id \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        if !ids.isEmpty {
            alarmLog.notice("Purged \(purged, privacy: .public)/\(ids.count, privacy: .public) orphan alarm(s) held by the system but tracked by no occurrence")
        }
        #else
        alarmLog.notice("[AlarmKit unavailable] would purge \(ids.count) orphan(s)")
        #endif
    }

    /// IDs of alarms currently in the countdown state. NOTE: with
    /// `CountdownDuration.preAlert` set, `.countdown` covers BOTH the pre-alert
    /// countdown (occurrence still in the future) and a running snooze
    /// (occurrence already fired) — callers disambiguate by occurrence date
    /// (see AlarmStore.reconcileSnoozes).
    func snoozingAlarmIDs() -> Set<UUID> {
        #if canImport(AlarmKit)
        guard let alarms = try? AlarmManager.shared.alarms else { return [] }
        return Set(alarms.filter { $0.state == .countdown }.map(\.id))
        #else
        return []
        #endif
    }

    @discardableResult
    func cancelOccurrences(_ dates: [Date], for item: AlarmItem) async -> [Date] {
        #if canImport(AlarmKit)
        // Cancel exactly the occurrences that were armed (the caller passes the
        // persisted `armedOccurrences`). Deterministic ids mean this works even
        // when a different process/launch did the arming.
        for date in dates {
            let id = occurrenceID(item: item, date: date)
            do {
                try AlarmManager.shared.cancel(id: id)
            } catch {
                // Routine: delete / eagerSilence pass ids that may never have been
                // armed or are already stopped. Debug level so it can't drown the
                // signal we actually care about (the verification below).
                alarmLog.debug("Cancel threw for id \(id, privacy: .public) @ \(date, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        guard !dates.isEmpty else { return [] }
        // Verify by ABSENCE — unlike verifying a schedule, this is unambiguous:
        // an id the system no longer lists is genuinely gone. Callers use the
        // result to decide whether it's safe to forget their cancel handle.
        guard let live = liveAlarmIDs() else {
            alarmLog.notice("Cancelled \(dates.count, privacy: .public) occurrence(s) — UNVERIFIED (alarm list unreadable)")
            return []   // unverifiable → callers must keep their handles
        }
        let cleared = dates.filter { !live.contains(occurrenceID(item: item, date: $0)) }
        if cleared.count == dates.count {
            alarmLog.notice("Cancelled \(cleared.count, privacy: .public) occurrence(s), verified gone")
        } else {
            alarmLog.error("Cancel INCOMPLETE: \(dates.count - cleared.count, privacy: .public) of \(dates.count, privacy: .public) occurrence(s) STILL held by the system")
        }
        return cleared
        #else
        alarmLog.notice("[AlarmKit unavailable] would cancel \(dates.count) alarm(s)")
        return dates
        #endif
    }

    #if canImport(AlarmKit)
    private func makeConfiguration(for item: AlarmItem, occurrence: Date) -> AlarmManager.AlarmConfiguration<PunctualMetadata> {
        let title = item.label.isEmpty ? "Alarm" : item.label

        // Fixed (one-shot) schedule for this concrete occurrence — we manage
        // recurrence/skip/pause ourselves via the engine.
        let schedule = Alarm.Schedule.fixed(occurrence)

        // Stop button is always present. Snooze maps to a secondary countdown
        // button when enabled, giving us a custom snooze duration.
        let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        let secondary: AlarmButton? = item.snooze.isEnabled
            ? AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
            : nil

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: stop,
            secondaryButton: secondary,
            secondaryButtonBehavior: item.snooze.isEnabled ? .countdown : nil
        )

        // When snooze is on, the secondary button transitions the alarm into a
        // COUNTDOWN (snooze) state. Without a countdown presentation that state
        // has NO Lock Screen / Dynamic Island surface — so the user sees no live
        // "rings in N min" timer, which reads as "snooze did nothing". Supplying
        // the countdown presentation restores the timer (Mode.Countdown carries
        // fireDate). `AlarmPresentation.Countdown` has no Stop slot; Stop in the
        // ALERT state is system-managed (Alert.stopButton deprecated on 26.1).
        // Whether the system also renders Stop on the SNOOZE surface is a device
        // behavior to validate; the in-app disable/delete path (see
        // AlarmScheduler) is the guaranteed way to cancel a running snooze.
        // Countdown presentation backs the SNOOZE state only (preAlert was
        // removed — see the countdown-duration note below).
        let presentation: AlarmPresentation
        if item.snooze.isEnabled {
            let countdownPresentation = AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: title)
            )
            presentation = AlarmPresentation(alert: alert, countdown: countdownPresentation)
        } else {
            presentation = AlarmPresentation(alert: alert)
        }

        let attributes = AlarmAttributes(
            presentation: presentation,
            // Brand-tinted (matches the user's chosen accent) — not the system blue.
            metadata: PunctualMetadata(alarmItemID: item.id, label: title, occurrence: occurrence),
            tintColor: BrandColor.currentAccent()
        )

        // Countdown duration: postAlert ONLY (custom snooze length).
        //
        // `preAlert` was tried in build 8 (system countdown surface at T−15)
        // and REMOVED after device validation in build 11: with preAlert set,
        // a .fixed-schedule alarm takes on timer shape, and firing UNATTENDED
        // (phone locked) auto-restarted the countdown instead of alerting —
        // i.e. the alarm "auto-snoozed" and never rang until unlocked. Apple's
        // own factories never combine schedule + preAlert; that combination is
        // undocumented territory. DO NOT reintroduce preAlert here. The T−15
        // heads-up remains covered by the pre-alert NOTIFICATION
        // (PreAlertNotificationManager — documented, validated).
        let postAlertSeconds: TimeInterval? = item.snooze.isEnabled
            ? TimeInterval(item.snooze.durationMinutes * 60) : nil
        let countdown = postAlertSeconds.map {
            Alarm.CountdownDuration(preAlert: nil, postAlert: $0)
        }

        // Sound: the imported sound (Library/Sounds CAF) for the alarm ring too.
        // DEVICE-VALIDATED 2026-07-19 (build 11): AlarmKit plays a runtime-
        // imported `.named` CAF for the alarm. Guarded by a file-existence
        // check — `.named` has no documented missing-file contract, and a
        // silent alarm is the one failure this product can never ship, so a
        // dead reference (deleted sound, stale Settings default) provably
        // falls back to `.default`.
        let alarmSound: AlertConfiguration.AlertSound
        if let name = item.soundName, !name.isEmpty,
           FileManager.default.fileExists(
               atPath: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                   .appendingPathComponent("Sounds").appendingPathComponent(name).path
           ) {
            alarmSound = .named(name)
        } else {
            alarmSound = .default
        }
        return AlarmManager.AlarmConfiguration(
            countdownDuration: countdown,
            schedule: schedule,
            attributes: attributes,
            sound: alarmSound
        )
    }
    #endif
}
