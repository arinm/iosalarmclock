import SwiftUI
import AlarmCore

/// Centralised premium design tokens. Calm, sleep-friendly, single warm accent,
/// soft depth, generous radius. Adapts to light/dark automatically.
enum Theme {
    // Resolves to the user's chosen accent (Pro themes); defaults to peach.
    static var accent: Color { ThemeManager.persistedAccentColor() }

    // Status tints — muted, harmonized with the accent (not raw system colors).
    static let skipTint = BrandColor.skip.opacity(0.16)
    static let skipFg = BrandColor.skip
    static let pauseTint = BrandColor.pause.opacity(0.16)
    static let pauseFg = BrandColor.pause
    static let offFg = Color.secondary

    // Pill / chip fills — one token set so every selectable pill looks identical.
    static var accentSoft: Color { accent.opacity(0.20) }
    static let neutralSoft = Color.secondary.opacity(0.12)

    /// Calm, sleep-friendly screen background used behind every screen so the
    /// glass cards read consistently in both light and dark.
    static var screenBackground: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // Radius scale — concentric: inner surfaces nest inside the card radius.
    static let cardRadius: CGFloat = 22
    static let radiusInner: CGFloat = 14
    static let radiusSmall: CGFloat = 10
    static let cardPadding: CGFloat = 18
    static let stackSpacing: CGFloat = 14

    /// Soft elevated card surface used everywhere.
    struct Card: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(cardPadding)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                .overlay(
                    // Semantic hairline so it shows in light AND dark.
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
                // Softer, more diffuse ambient shadow (was a heavy dark drop that
                // muddied light mode).
                .shadow(color: .black.opacity(0.10), radius: 18, y: 6)
        }
    }
}

/// The app's own brand mark (clock + skip glyph) as a themeable template image —
/// replaces generic SF Symbols (sparkles / alarm.waves) so branding looks
/// intentional, not templated.
struct BrandMark: View {
    var size: CGFloat = 56
    var color: Color = Theme.accent
    var body: some View {
        Image("PunctualMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

extension View {
    func punctualCard() -> some View { modifier(Theme.Card()) }

    /// Place the calm brand background behind a screen and hide the default
    /// scroll/form background so the glass language holds everywhere.
    func punctualBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.screenBackground)
    }
}

/// Human, friendly rendering of an `AlarmStatus`. Keeps all UI copy in one place
/// so wording stays consistent ("Skip today", "still active", "Paused until…").
enum StatusPresenter {
    static func line(_ status: AlarmStatus, now: Date = .now) -> (text: String, tint: Color, fg: Color) {
        switch status {
        case .off:
            // OFF is the most consequential state — give it a clear, distinct chip
            // (not an empty pill) so it can't be mistaken for "skipped".
            return ("Off - won't ring", Color.secondary.opacity(0.14), Theme.offFg)
        case .completed:
            return ("Completed", Color.secondary.opacity(0.10), Theme.offFg)
        case .noUpcoming:
            return ("No upcoming alarm", Color.secondary.opacity(0.10), Theme.offFg)
        case .scheduled(let next):
            // Subtle neutral fill so every card's status line shares one shape.
            return (CountdownFormatter.ringsIn(next, from: now), Color.primary.opacity(0.05), .primary)
        case .skippedToday(let next):
            return ("Skipped today · still active - next \(Self.shortNext(next))", Theme.skipTint, Theme.skipFg)
        case .paused(let until, let next):
            let tail = next.map { " - next \(Self.shortNext($0))" } ?? ""
            return ("Paused until \(Self.dayLabel(until))\(tail)", Theme.pauseTint, Theme.pauseFg)
        }
    }

    static func shortNext(_ date: Date) -> String {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    static func dayLabel(_ day: DateOnly) -> String {
        guard let date = day.startOfDay(in: .current) else { return day.description }
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }
}
