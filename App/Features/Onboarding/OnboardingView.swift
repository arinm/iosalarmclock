import SwiftUI

/// Screen 1 — value + the two permission requests, with friendly (non-scary)
/// copy and graceful handling if either is denied.
struct OnboardingView: View {
    @Environment(PermissionManager.self) private var permissions
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
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
                           detail: "A pre-alert before the alarm goes off.")
                FeatureRow(icon: "forward.end.fill", title: "Skip just today",
                           detail: "One tap — tomorrow stays armed.")
            }
            .padding()
            .punctualCard()

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Task { await requestPermissions() }
                } label: {
                    Text(requesting ? "Requesting…" : "Enable smart alarms")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(requesting)

                Text("Smart alarms need permission to ring and to send pre-alerts before they go off.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if permissions.alarmKitState == .denied {
                    PermissionDeniedNote(
                        text: "Alarms can't ring until you allow this in Settings.",
                        showsSettingsLink: true
                    )
                }
            }
        }
        .padding()
    }

    private func requestPermissions() async {
        requesting = true
        await permissions.requestAlarmKit()
        await permissions.requestNotifications() // pre-alerts; optional
        requesting = false
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
