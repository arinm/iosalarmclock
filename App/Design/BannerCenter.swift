import SwiftUI

/// A single, app-wide transient confirmation banner with optional Undo. Used to
/// make *every* state change reassuring and reversible — especially to remove the
/// old asymmetry where "Skip today" was confirmed but disabling an alarm was
/// silent. One source of truth so skip / disable / pause all look consistent.
@MainActor
@Observable
final class BannerCenter {
    enum Kind { case skip, disabled, paused, neutral }

    struct Banner: Identifiable, Equatable {
        let id: UUID
        var kind: Kind
        var title: String
        var subtitle: String?
        /// The alarm this confirmation belongs to, so it renders inline under
        /// that card (nil = not tied to a specific alarm).
        var alarmID: UUID?
        // Undo is intentionally excluded from Equatable (closures aren't comparable).
        var undo: (@MainActor () async -> Void)?

        static func == (l: Banner, r: Banner) -> Bool {
            l.id == r.id && l.kind == r.kind && l.title == r.title && l.subtitle == r.subtitle && l.alarmID == r.alarmID
        }
    }

    private(set) var current: Banner?
    private var dismissTask: Task<Void, Never>?

    func show(_ kind: Kind, title: String, subtitle: String? = nil, alarmID: UUID? = nil,
              undo: (@MainActor () async -> Void)? = nil) {
        let banner = Banner(id: UUID(), kind: kind, title: title, subtitle: subtitle, alarmID: alarmID, undo: undo)
        current = banner
        // Authoritative auto-dismiss here (not in the view) so a banner always
        // clears even if no card is on screen to render its timer.
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { self?.dismiss(id: banner.id) }
        }
    }

    func dismiss(id: UUID) {
        if current?.id == id { current = nil }
    }

    func dismiss() { dismissTask?.cancel(); current = nil }
}
