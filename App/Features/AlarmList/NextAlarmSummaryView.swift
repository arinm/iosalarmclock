import SwiftUI
import AlarmCore

/// The hero "Next alarm" card: big ring time, live "Rings in…" countdown, and a
/// progress ring showing how far through the wait we are.
struct NextAlarmSummaryView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(ThemeManager.self) private var theme
    /// Hero time scales with Dynamic Type (capped for layout sanity).
    @ScaledMetric(relativeTo: .largeTitle) private var heroTimeSize: CGFloat = 52
    let now: Date
    @State private var pulse = false

    var body: some View {
        let upcoming = store.nextUpAlarm(now: now)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NEXT ALARM")
                    .font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)

                if let upcoming {
                    timeView(upcoming.fireDate)
                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.caption)
                        Text("Rings in").foregroundStyle(.secondary)
                        Text(CountdownFormatter.string(until: upcoming.fireDate, from: now))
                            .foregroundStyle(theme.accentColor).fontWeight(.semibold)
                    }
                    .font(.subheadline)
                } else {
                    // This view only renders when alarms EXIST, so "nothing
                    // upcoming" means they're all off — or enabled but with no
                    // future fire (completed one-time, paused, skipped).
                    let hasEnabled = store.allAlarms().contains { $0.isEnabled }
                    Text(hasEnabled ? "No upcoming alarms" : "All alarms are off")
                        .font(.title.weight(.bold))
                    Text(hasEnabled ? "They've already rung, or are paused." : "Turn one on to see it here.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if upcoming != nil {
                // Decorative brand medallion with a subtle, slow "breathing" pulse.
                ZStack {
                    Circle().strokeBorder(theme.accentColor.opacity(0.35), lineWidth: 5)
                    BrandMark(size: 34, color: theme.accentColor)
                }
                .frame(width: 70, height: 70)
                .scaleEffect(pulse ? 1.06 : 0.94)
                .opacity(pulse ? 1.0 : 0.6)
                .onAppear {
                    guard !pulse else { return } // idempotent: don't stack animations on re-appear
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [theme.accentColor.opacity(0.22), theme.accentColor.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.cardRadius + 4, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius + 4, style: .continuous)
                .strokeBorder(theme.accentColor.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: theme.accentColor.opacity(0.18), radius: 18, y: 8)
    }

    /// Big "6:30" with a smaller AM/PM suffix (24h locales show just the time).
    private func timeView(_ date: Date) -> some View {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("jmm")
        let s = f.string(from: date)
        // Split trailing AM/PM if present.
        let parts = s.components(separatedBy: " ")
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(parts.first ?? s)
                .font(.system(size: min(heroTimeSize, 76), weight: .bold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            if parts.count > 1 {
                Text(parts[1]).font(.title3.weight(.bold)).foregroundStyle(.secondary)
            }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }

}
