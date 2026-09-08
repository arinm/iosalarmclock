import SwiftUI
import StoreKit

/// Asks for an App Store rating only after Punctual has actually done its job.
///
/// The trigger is MORNINGS SERVED — distinct calendar days on which one of the
/// user's alarms really fired — not launches and not days-since-install.
/// Someone who has been woken three times has an opinion worth asking for;
/// someone who merely opened the app three times may never have heard it ring,
/// and asking them is how apps collect two-star reviews.
///
/// Counting stops the moment we ask. iOS caps how often the rating sheet can
/// appear anyway, so a request that gets swallowed is spent either way — we
/// only ever spend it once, on a user we know the app has served.
@MainActor
enum AppReviewPrompt {
    private static let morningsKey = "reviewMorningsServed"
    private static let lastDayKey = "reviewLastCountedDay"
    private static let askedKey = "reviewAsked"

    /// Mornings the app must have served before we ask.
    static let requiredMornings = 3

    /// Record that alarms fired, at most once per calendar day.
    ///
    /// Feed this PAST-DATED `armedOccurrences`, never `recentlyFiredOccurrences`.
    /// The latter looks like a fire log but is snooze bookkeeping: it is only
    /// written while `snooze.isEnabled` (AlarmScheduler ~L120), pruned to a 12h
    /// window, and wiped when an alarm is disabled — so it would silently never
    /// count a morning for a snooze-off user.
    ///
    /// A past-dated entry in `armedOccurrences` is the honest signal: the
    /// calculator never emits a skipped or paused day (NextOccurrenceCalculator
    /// `guard !s.isSuppressed(day)`), and the scheduler stores only occurrences
    /// that ACTUALLY armed. So it means "we really scheduled this ring and its
    /// time has passed". The one miscount left is a phone that was off, which
    /// costs us nothing worse than asking a day later.
    static func noteFired(_ dates: [Date], now: Date = .now, calendar: Calendar = .current) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: askedKey) else { return }
        guard dates.contains(where: { calendar.isDate($0, inSameDayAs: now) }) else { return }

        let today = calendar.startOfDay(for: now)
        if let last = d.object(forKey: lastDayKey) as? Date,
           calendar.isDate(last, inSameDayAs: today) { return }

        d.set(today, forKey: lastDayKey)
        d.set(d.integer(forKey: morningsKey) + 1, forKey: morningsKey)
    }

    /// Ask, but only if the mornings have been earned and we've never asked.
    static func askIfEarned(_ requestReview: RequestReviewAction) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: askedKey),
              d.integer(forKey: morningsKey) >= requiredMornings else { return }
        d.set(true, forKey: askedKey)
        requestReview()
    }
}
