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

    /// Split dropped URLs into those whose files exist (order preserved) and a
    /// count of missing ones. `exists` is injected so the rule stays testable;
    /// the caller passes a FileManager-backed check. Missing files would enter
    /// the setlist and get silently skipped at playback — reject them up front.
    public static func partitionExisting(
        _ urls: [URL],
        exists: (URL) -> Bool
    ) -> (valid: [URL], missingCount: Int) {
        let valid = urls.filter(exists)
        return (valid, urls.count - valid.count)
    }

    public static func missingFileNote(_ count: Int) -> String {
        "\(count) file\(count == 1 ? "" : "s") not found"
    }

    /// Combined post-drop feedback line; nil when nothing was skipped.
    /// Duplicate skips mention the added count; a pure missing-file skip is
    /// reported on its own.
    public static func dropFeedbackMessage(added: Int, skippedDuplicates: Int, missing: Int) -> String? {
        if skippedDuplicates > 0 {
            let base = "Added \(added) — \(skippedDuplicates) already in set"
            return missing > 0 ? base + " — " + missingFileNote(missing) : base
        }
        return missing > 0 ? missingFileNote(missing) : nil
    }
}
