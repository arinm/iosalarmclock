import SwiftUI

/// A single, app-wide transient confirmation banner with optional Undo. Used to
/// make *every* state change reassuring and reversible — especially to remove the
/// old asymmetry where "Skip today" was confirmed but disabling an alarm was
/// silent. One source of truth so skip / disable / pause all look consistent.
@MainActor
@Observable
final class BannerCenter {
    enum Kind { case skip, disabled, enabled, paused, neutral }

    struct Banner: Identifiable, Equatable {
        let id: UUID
        var kind: Kind
        var title: String
        var subtitle: String?
        // Undo is intentionally excluded from Equatable (closures aren't comparable).
        var undo: (@MainActor () async -> Void)?

        static func == (l: Banner, r: Banner) -> Bool {
            l.id == r.id && l.kind == r.kind && l.title == r.title && l.subtitle == r.subtitle
        }
    }

    private(set) var current: Banner?

    func show(_ kind: Kind, title: String, subtitle: String? = nil, undo: (@MainActor () async -> Void)? = nil) {
        current = Banner(id: UUID(), kind: kind, title: title, subtitle: subtitle, undo: undo)
    }

    func dismiss(id: UUID) {
        if current?.id == id { current = nil }
    }

    func dismiss() { current = nil }
}
