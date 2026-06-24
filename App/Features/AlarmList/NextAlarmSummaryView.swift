import SwiftUI
import AlarmCore

/// The big hero header: "Next alarm · Tomorrow 08:00 · Rings in 12h 18m".
struct NextAlarmSummaryView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(ThemeManager.self) private var theme
    let now: Date

    var body: some View {
        let upcoming = store.nextUpAlarm(now: now)
        VStack(alignment: .leading, spacing: 4) {
            Text("Next alarm")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let upcoming {
                // The live countdown IS the hero — the reason this beats Clock.
                Text(CountdownFormatter.string(until: upcoming.fireDate, from: now))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.accentColor)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(StatusPresenter.shortNext(upcoming.fireDate))
                    .font(.headline.weight(.medium))
            } else {
                Text("Nothing scheduled")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Add an alarm to see exactly when it'll ring")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [theme.accentColor.opacity(0.22), theme.accentColor.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.cardRadius + 4, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius + 4, style: .continuous)
                .strokeBorder(theme.accentColor.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: theme.accentColor.opacity(0.18), radius: 18, y: 8)
    }
}
