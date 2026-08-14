# Punctual — *Skip today, never forget tomorrow*

The smart alarm Apple's Clock should have had. A focused, premium,
iOS 26 native alarm manager built around one workflow:

> **Create alarm → see how long until it rings → get a pre-alert → skip only today → alarm stays active tomorrow.**

Not a bloated alarm app. No sleep tracking, no math puzzles, no social alarms, no
music streaming. Just the alarm management iPhone users are missing, with
Apple-native polish.

---

## Why this exists (the gap)

Apple Clock is reliable but thin: no "rings in 7h 42m" countdown, no pre-alert,
no skip-just-today, no vacation pause, no per-day exceptions. Galarm has some of
these but is cluttered and dated. Alarmy is a heavy "punish the sleeper" app.
**Nobody owns "Apple polish + deep alarm management + obsessive skip-today
focus."** iOS 26's **AlarmKit** finally makes real third-party alarms possible,
so the moment is now.

---

## Architecture

```
AlarmCore/                 ← pure Swift package (Foundation only), unit-tested
  Sources/AlarmCore/
    Weekday / DateOnly / DateRange / Settings / AlarmSchedule
    NextOccurrenceCalculator    ← the scheduling engine (heart of the app)
    CountdownFormatter
  Tests/AlarmCoreTests/         ← 18 tests, run with `swift test`

App/                       ← the iOS 26 SwiftUI app
  PunctualApp.swift             ← entry, DI graph, re-arm on foreground
  Persistence/   AlarmItem (@Model), AlarmStore
  Scheduling/    AlarmScheduler, BackgroundRefreshManager, LiveActivityManager
  AlarmKitIntegration/  AlarmKitManager (+ AlarmKitManaging protocol)
  Notifications/ PreAlertNotificationManager, NotificationActionHandler
  Permissions/   PermissionManager
  Pro/           ProFeatureManager, StoreManager (StoreKit 2)
  Shared/        SharedModelContainer, SkipTodayIntent, SkipNextAlarmIntent,
                 PunctualActivityAttributes  (compiled into app + widget)
  Design/        Theme, StatusPresenter
  Features/      AlarmList, AlarmEditor, AlarmDetail, Onboarding, Settings, Paywall

PunctualWidget/            ← widget extension target
  NextAlarmWidget          ← Home/Lock Screen widget (+ interactive Skip today)
  AlarmLiveActivity        ← Lock Screen + Dynamic Island countdown Live Activity
  PunctualWidgetBundle
```

**Key design choice:** the recurrence rules (weekdays, one-time date, **skip
dates, pause ranges, exceptions**) live in *our* engine, not AlarmKit, because
AlarmKit has no "skip one occurrence" primitive. `NextOccurrenceCalculator` is a
pure function of `(schedule, now, calendar)` → next fire date(s); the app arms
those concrete dates as one-time AlarmKit alarms and re-arms a small look-ahead
window on launch / foreground / fire. That is why the engine is decoupled and
exhaustively tested.

---

## How to run

### 1. Unit tests (no Xcode project needed — works right now)
```bash
cd AlarmCore
swift test          # 18 tests covering every scheduling edge case
```

### 2. The iOS app
Requires **Xcode 26** and an **iOS 26** simulator/device.
```bash
brew install xcodegen        # one-time
xcodegen generate            # creates Punctual.xcodeproj from project.yml
open Punctual.xcodeproj
```
Select the **Punctual** scheme → an iOS 26 simulator → Run.

> Note: AlarmKit alarms ring most faithfully on a **real device**. The simulator
> is fine for UI, scheduling logic, and pre-alert notifications.

---

## AlarmKit limitations & how Punctual handles them

| Limitation | Handling |
|---|---|
| **No "skip one occurrence" primitive** | We own recurrence in `NextOccurrenceCalculator`; skip = add the day to `skippedOccurrenceDates`, recompute, re-arm. |
| **Re-arm requires app activity** (we use one-shot alarms, not OS infinite recurrence) | Arm the next **2** occurrences; re-arm on every foreground, mutation, and skip. Documented in Settings → Reliability. |
| **Custom audio constrained** | Use bundled/default sounds via the alert config (arbitrary music out of scope). |
| **Pre-alert is not an AlarmKit feature** | Implemented as a local `UserNotifications` heads-up carrying *Skip today / Open* — the *only* notification use; it is never the alarm. |
| **Two separate permissions** | `PermissionManager` tracks both; UI degrades gracefully (alarms still ring if notifications are denied). |
| **iOS 26 minimum** | Hard requirement — a notification-only "alarm" would be fake, which we refuse to ship. |

The exact AlarmKit symbol surface shifted across iOS 26 betas. All AlarmKit code
is isolated in `App/AlarmKitIntegration/AlarmKitManager.swift` behind the
`AlarmKitManaging` protocol — if a symbol name differs in your SDK, fix it there
only; nothing else depends on AlarmKit. Likewise verify
`NSAlarmKitUsageDescription` against your SDK (in `App/Info.plist`).

---

## MVP acceptance criteria — status

- ✅ Create a recurring weekday 08:00 alarm (editor, Weekdays preset)
- ✅ "Rings in Xh Ym" — live, under the picker and on every card/summary
- ✅ Next valid occurrence shown (summary + per card)
- ✅ Pre-alert 15 min before (default) with **Skip today / Open** actions
- ✅ Skip today from notification → today suppressed, alarm stays enabled,
  next occurrence re-armed, UI confirms "still active — next …"
- ✅ Pause an alarm for a date range
- ✅ One-time date-specific alarm
- ✅ Custom snooze duration + repeat count
- ✅ Scheduling survives restart (SwiftData + re-arm on launch)
- ✅ No private APIs; real alarms via AlarmKit
- ✅ Unit tests cover next-occurrence calculation (**18 passing**)
- ✅ "Project builds" — `swift test` passes (18/18) **and** the app target
  compiles clean: `xcodegen generate` then
  `xcodebuild -scheme Punctual -destination 'generic/platform=iOS Simulator' build`
  → **BUILD SUCCEEDED** on Xcode 26 (app icon is a placeholder set).

---

## Free vs Pro (placeholder)

**Free:** basic alarms, 15-min pre-alert, skip today, repeat days, basic snooze.
**Pro:** custom pre-alert timing, multiple pre-alerts, vacation pause, advanced
snooze, alarm groups, widgets, Live Activity, themes. Gated by
`ProFeatureManager` (local flag now; swap for StoreKit 2 later — one file).

---

## Known limitations / not in MVP

- App icon is a placeholder (add to `Assets.xcassets`).
- Pro purchases are simulated (a demo toggle), not StoreKit yet.
- No widgets / Live Activity customisation yet (AlarmKit provides the default
  Live Activity; bespoke UI is a Pro follow-up).
- Snooze "remaining count" is configured but not yet surfaced live on the alert
  (depends on AlarmKit alert-state callbacks).

## Next steps

1. Run on a physical iOS 26 device to validate real ring-through-silent behaviour.
2. Verify AlarmKit symbol names against the shipping SDK in `AlarmKitManager`.
3. ✅ `BGAppRefreshTask` top-up implemented (`BackgroundRefreshManager`, id
   `com.punctual.app.refresh`) — registered at launch, scheduled on background.
4. ✅ StoreKit 2 wired (`StoreManager`, non-consumable `com.punctual.app.pro`);
   `ProFeatureManager.isPro` syncs to the live entitlement; paywall does real
   purchase/restore. For local testing select **Punctual.storekit** in the scheme
   (Edit Scheme → Run → Options → StoreKit Configuration).
5. ✅ WidgetKit "next alarm + skip today" interactive widget (`PunctualWidget/`)
   reusing the shared `SkipTodayIntent`.
6. ✅ Bespoke **Live Activity** (`AlarmLiveActivity` + `LiveActivityManager`):
   Lock Screen + Dynamic Island countdown with a Skip today button, shown once an
   alarm is within 8h (ActivityKit's runtime budget).
7. ✅ **App Shortcuts** (`SkipNextAlarmIntent` + `PunctualShortcuts`): "Hey Siri,
   skip today's alarm in Punctual", plus Spotlight & Shortcuts app.
8. ✅ **Alarm Detail** screen (skipped days, pause ranges, snooze, Pro teasers).
9. ✅ App icon rendered (`App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`).

Remaining: on-device AlarmKit validation, confirming AlarmKit symbol names against
the shipping SDK, an onboarding illustration, and real App Store Connect product
setup for Pro.

Also done in recent passes: shared App Group store (app↔widget), deterministic
cross-process AlarmKit cancel, `BGAppRefreshTask` top-up, Settings defaults
applied to new alarms, and an auto-dismissing skip-today banner.
