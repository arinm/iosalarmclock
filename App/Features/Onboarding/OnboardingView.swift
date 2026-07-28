import SwiftUI

/// Screen 1 — value proposition + the two permission requests as SEPARATE,
/// explained steps (alarms = required, heads-up = optional benefit). One
/// combined request used to stack two system dialogs back-to-back and RootView
/// tore this screen down between them — the first-run experience read as a bug,
/// and the unexplained notifications prompt got reflex-denied, silently killing
/// the heads-up feature.
struct OnboardingView: View {
    @Environment(PermissionManager.self) private var permissions
    /// Called when the flow finishes (both steps resolved or heads-up skipped).
    var onDone: () -> Void = {}

    private enum Step { case alarms, headsUp }
    @State private var step: Step = .alarms
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            switch step {
            case .alarms: alarmsStep
            case .headsUp: headsUpStep
            }
            Spacer()
            controls
        }
        .padding()
        .animation(.snappy, value: step == .headsUp)
    }

    // MARK: Step 1 — the value pitch + the required alarm permission

    private var alarmsStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 14) {
                BrandMark(size: 76)
                Text("Skip today,\nnever forget tomorrow")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("The Android-style smart alarm Apple Clock should have had.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "timer", title: "See the countdown",
                           detail: "Always know how long until it rings.")
                FeatureRow(icon: "bell.badge", title: "Get a heads-up",
                           detail: "A friendly nudge before the alarm goes off.")
                FeatureRow(icon: "forward.end.fill", title: "Skip just today",
                           detail: "One tap - tomorrow stays armed.")
            }
            .padding()
            .punctualCard()
        }
    }

    // MARK: Step 2 — the heads-up, explained BEFORE its system dialog

    private var headsUpStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 14) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 56)).foregroundStyle(Theme.accent)
                Text("One more thing -\nthe heads-up")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("A friendly notification before each alarm, with a Skip today button right on it. This is what makes Punctual smart - and it needs notification permission.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .punctualCard()
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 10) {
            switch step {
            case .alarms:
                Button {
                    Task {
                        requesting = true
                        let granted = await permissions.requestAlarmKit()
                        requesting = false
                        // Advance only on grant — a denial deserves an explicit
                        // acknowledgment (note below), not a silent breeze-past.
                        if granted { step = .headsUp }
                    }
                } label: {
                    Text(requesting ? "Asking…" : "Allow alarms")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(requesting)

                Text("Required - this is how Punctual rings, even in silent mode.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if permissions.alarmKitState == .denied {
                    PermissionDeniedNote(
                        text: "Alarms can't ring until you allow this in Settings.",
                        showsSettingsLink: true
                    )
                    Button("Continue anyway") { step = .headsUp }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

            case .headsUp:
                Button {
                    Task {
                        requesting = true
                        await permissions.requestNotifications()
                        requesting = false
                        onDone()
                    }
                } label: {
                    Text(requesting ? "Asking…" : "Allow the heads-up")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(requesting)

                // Notifications are a benefit, not a requirement — always give
                // a quiet way out. The alarm itself doesn't depend on this.
                Button("Not now") { onDone() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String, title: String, detail: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct PermissionDeniedNote: View {
    let text: String
    var showsSettingsLink: Bool = false
    var body: some View {
        VStack(spacing: 6) {
            Text(text).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center)
            if showsSettingsLink, let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url).font(.caption.weight(.semibold))
            }
        }
        .padding(10)
        .background(Theme.pauseTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
