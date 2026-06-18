import Foundation

/// Pure rules that keep the setlist's "played" entries a contiguous block at the top
/// and decide which entry should play next. AppKit/SwiftUI-free so it is unit-testable.
///
/// Invariant the rules enforce: played entries form a top prefix. You may only extend
/// that prefix downward (`sanitizedMarkPlayed`) or shrink it from the bottom upward
/// (`sanitizedUnplay`) — never punch a hole in the middle. The "next to play" is always
/// the first not-yet-played entry from the top.
public enum SetlistOrderRules {

    /// Index of the first entry that is not yet played, scanning top-down, or `nil`
    /// when every entry is played. This is the entry that should play next.
    public static func firstUnplayedIndex(played: [Bool]) -> Int? {
        played.firstIndex(of: false)
    }

    /// Length of the contiguous run of played entries at the top of the list.
    public static func playedPrefixLength(played: [Bool]) -> Int {
        played.prefix(while: { $0 }).count
    }

    /// The subset of `targets` that may flip from played → not-played while keeping the
    /// played prefix contiguous. Only played entries forming a run at the bottom edge of
    /// the prefix qualify — selecting a middle one without the ones below it un-plays nothing
    /// (that would leave a played entry stranded below a queued one).
    public static func sanitizedUnplay(played: [Bool], targets: Set<Int>) -> Set<Int> {
        let prefix = playedPrefixLength(played: played)
        guard prefix > 0 else { return [] }
        var allowed: Set<Int> = []
        var i = prefix - 1
        while i >= 0, targets.contains(i) {
            allowed.insert(i)
            i -= 1
        }
        return allowed
    }

    /// The subset of `targets` that may flip from not-played → played while keeping the
    /// played prefix contiguous. Only not-played entries forming a run starting right at the
    /// prefix boundary qualify — marking a lower entry without the boundary one plays nothing
    /// (that would create a played island below queued entries).
    public static func sanitizedMarkPlayed(played: [Bool], targets: Set<Int>) -> Set<Int> {
        let prefix = playedPrefixLength(played: played)
        var allowed: Set<Int> = []
        var i = prefix
        while i < played.count, targets.contains(i), !played[i] {
            allowed.insert(i)
            i += 1
        }
        return allowed
    }
}
