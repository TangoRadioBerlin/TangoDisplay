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

    public static func unreadableNote(_ count: Int) -> String {
        "\(count) item\(count == 1 ? "" : "s") could not be read"
    }

    public static func unsupportedNote(_ count: Int) -> String {
        "\(count) unsupported file type\(count == 1 ? "" : "s")"
    }

    /// Audio file extensions the built-in player accepts. Single source of
    /// truth for the setlist's insert filter and the drop pre-filter.
    public static let supportedAudioExtensions: Set<String> =
        ["mp3", "m4a", "aiff", "aif", "wav", "flac", "caf", "opus"]

    /// Split dropped URLs into supported audio files (order preserved) and a
    /// count of the rest, so unsupported types are reported instead of being
    /// dropped silently inside the setlist insert.
    public static func partitionSupported(
        _ urls: [URL],
        supportedExtensions: Set<String> = supportedAudioExtensions
    ) -> (supported: [URL], unsupportedCount: Int) {
        let supported = urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
        return (supported, urls.count - supported.count)
    }

    /// Combined post-drop feedback line; nil when nothing was skipped.
    /// Duplicate skips mention the added count; a pure missing-file skip is
    /// reported on its own.
    public static func dropFeedbackMessage(added: Int, skippedDuplicates: Int, missing: Int) -> String? {
        dropFeedbackMessage(added: added, skippedDuplicates: skippedDuplicates, missing: missing,
                            unreadable: 0, unsupported: 0)
    }

    /// Full post-drop feedback. `unreadable` = items the drop could not turn
    /// into a file URL (the requested-vs-resolved shortfall); `unsupported` =
    /// resolved files with a non-audio extension. Any shortfall leads with
    /// "Added N of M" (or "Nothing added") so a partial multi-track drop is
    /// never mistaken for a complete one. Notes follow in a fixed order:
    /// duplicates, missing, unreadable, unsupported. nil when nothing was skipped.
    public static func dropFeedbackMessage(added: Int, skippedDuplicates: Int, missing: Int,
                                           unreadable: Int, unsupported: Int) -> String? {
        var notes: [String] = []
        if skippedDuplicates > 0 { notes.append("\(skippedDuplicates) already in set") }
        if missing > 0 { notes.append(missingFileNote(missing)) }
        if unreadable > 0 { notes.append(unreadableNote(unreadable)) }
        if unsupported > 0 { notes.append(unsupportedNote(unsupported)) }
        guard !notes.isEmpty else { return nil }

        let head: String?
        if unreadable > 0 {
            head = added > 0 ? "Added \(added) of \(added + unreadable)" : "Nothing added"
        } else if skippedDuplicates > 0 || unsupported > 0 {
            head = added > 0 ? "Added \(added)" : (skippedDuplicates > 0 ? "Added 0" : "Nothing added")
        } else {
            head = nil   // missing-only keeps its standalone wording
        }
        return ([head].compactMap { $0 } + notes).joined(separator: " — ")
    }
}
