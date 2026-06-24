import AppIntents
import SwiftData
import Foundation

/// Lets the user pick WHICH alarm the widget shows (or leave empty for "next").
/// Compiled into both the app and widget targets.
struct AlarmEntity: AppEntity, Identifiable {
    let id: UUID
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Alarm" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
    static var defaultQuery = AlarmEntityQuery()
}

struct AlarmEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [AlarmEntity] {
        Self.all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AlarmEntity] { Self.all() }

    @MainActor
    static func all() -> [AlarmEntity] {
        let ctx = ModelContext(SharedModelContainer.make())
        let items = (try? ctx.fetch(FetchDescriptor<AlarmItem>())) ?? []
        let f = DateFormatter(); f.timeStyle = .short
        return items.map { item in
            var comps = DateComponents(); comps.hour = item.hour; comps.minute = item.minute
            let timeText = f.string(from: Calendar.current.date(from: comps) ?? .now)
            return AlarmEntity(id: item.id, title: item.label.isEmpty ? timeText : "\(item.label) · \(timeText)")
        }
    }
}

/// Widget configuration: optionally pin a specific alarm; empty = soonest upcoming.
struct SelectAlarmIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Alarm" }
    static var description: IntentDescription { IntentDescription("Show a specific alarm, or the next one across all alarms.") }

    @Parameter(title: "Alarm (leave empty for the next one)")
    var alarm: AlarmEntity?

    init() {}
}
