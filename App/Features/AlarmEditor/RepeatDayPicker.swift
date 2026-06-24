import SwiftUI
import AlarmCore

/// Beautiful, tappable Mon–Sun selector with quick presets.
struct RepeatDayPicker: View {
    @Binding var selection: Set<Weekday>

    // Display order Mon...Sun for a European-friendly week start.
    private let ordered: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(ordered, id: \.self) { day in
                    let on = selection.contains(day)
                    Button {
                        if on { selection.remove(day) } else { selection.insert(day) }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(day.minimalLabel)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(on ? Theme.accent : Color.secondary.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(on ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                presetButton("Weekdays", Weekday.weekdays)
                presetButton("Weekends", Weekday.weekend)
                presetButton("Every day", Set(Weekday.allCases))
            }
        }
    }

    private func presetButton(_ title: String, _ set: Set<Weekday>) -> some View {
        Button(title) { selection = set }
            .font(.caption.weight(.medium))
            .buttonStyle(.bordered)
            .tint(selection == set ? Theme.accent : .secondary)
    }
}

/// Pause-for-a-range sheet used from the editor (and surfaced as a Pro feature).
struct PauseRangeSheet: View {
    @Bindable var alarm: AlarmItem
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
                    Text("The alarm won't ring during this range, then resumes automatically. Great for holidays.")
                }
            }
            .navigationTitle("Pause Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pause") {
                        let range = DateRange(
                            start: DateOnly(date: start, calendar: .current),
                            end: DateOnly(date: end, calendar: .current)
                        )
                        Task { await store.pause(alarm, range: range) }
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
        }
    }
}
