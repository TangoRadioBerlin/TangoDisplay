import Foundation

/// Pure rules for evaluating incoming dropped URLs against the current setlist.
/// Kept in Core so the logic is unit-testable without AppKit.
public enum SetlistDropRules {

    public struct DuplicateSummary {
        public let duplicateCount: Int
        public let anyAlreadyPlayed: Bool
    }

    /// Count how many of the `incoming` URLs are already in `existing`, and whether
    /// any of those duplicates have been played. `played` is a subset of `existing`.
    public static func duplicateSummary(
        incoming: [URL],
        existing: Set<URL>,
        played: Set<URL>
    ) -> DuplicateSummary {
        let dups = incoming.filter { existing.contains($0) }
        let anyPlayed = dups.contains { played.contains($0) }
        return DuplicateSummary(duplicateCount: dups.count, anyAlreadyPlayed: anyPlayed)
    }
}
