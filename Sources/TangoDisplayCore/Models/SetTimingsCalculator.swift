import Foundation

/// Pure remaining-set-time arithmetic for the Set Timings window. AppKit/SwiftUI-free
/// so it is unit-testable.
///
/// Two assumptions a DJ relies on are baked in here:
/// - **Cortinas** count as at most `cortinaAssumedPlay` seconds (DJs fade them after ~1 min),
///   capped at the cortina's real length; an unknown-length cortina is assumed to run the full
///   assumed time.
/// - **Auto-gap** pauses between tracks add to the remaining time, so the projected end time
///   isn't optimistically early.
public enum SetTimingsCalculator {

    public struct Item: Equatable {
        public var duration: TimeInterval      // known length in seconds; 0 = unknown
        public var isCortina: Bool
        public var elapsed: TimeInterval?      // set only for the currently-playing/current entry
        public var contributes: Bool           // false for already-played (non-current) entries → skipped
        public var addLeadingGap: Bool         // count an auto-gap pause before this entry

        public init(duration: TimeInterval, isCortina: Bool, elapsed: TimeInterval? = nil,
                    contributes: Bool, addLeadingGap: Bool) {
            self.duration = duration
            self.isCortina = isCortina
            self.elapsed = elapsed
            self.contributes = contributes
            self.addLeadingGap = addLeadingGap
        }
    }

    /// Effective remaining play length of one entry (before gaps), applying the cortina cap
    /// and subtracting `elapsed` for the current entry.
    public static func effectiveRemaining(_ item: Item, cortinaAssumedPlay: TimeInterval) -> TimeInterval {
        let base: TimeInterval
        if item.isCortina {
            base = item.duration > 0 ? min(item.duration, cortinaAssumedPlay) : cortinaAssumedPlay
        } else {
            base = item.duration
        }
        if let elapsed = item.elapsed {
            return max(0, base - elapsed)
        }
        return base
    }

    /// Total remaining set time: the effective remaining length of every contributing entry,
    /// plus an `autoGap` pause before each contributing entry flagged `addLeadingGap`.
    public static func remainingSeconds(items: [Item], autoGap: TimeInterval,
                                        cortinaAssumedPlay: TimeInterval) -> TimeInterval {
        var total: TimeInterval = 0
        for item in items where item.contributes {
            total += effectiveRemaining(item, cortinaAssumedPlay: cortinaAssumedPlay)
            if item.addLeadingGap { total += max(0, autoGap) }
        }
        return total
    }
}
