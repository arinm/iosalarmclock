import Foundation

/// An inclusive range of calendar days — used for "Paused until Monday" /
/// vacation holds. Both ends are inclusive: a single-day pause has start == end.
public struct DateRange: Codable, Hashable, Sendable {
    public let start: DateOnly
    public let end: DateOnly

    /// Normalises so `start <= end` regardless of argument order.
    public init(start: DateOnly, end: DateOnly) {
        if start <= end { self.start = start; self.end = end }
        else { self.start = end; self.end = start }
    }

    public func contains(_ day: DateOnly) -> Bool {
        day >= start && day <= end
    }
}
