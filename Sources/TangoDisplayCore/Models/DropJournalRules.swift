import Foundation

/// Formatting and size discipline for the on-disk drop journal. The unified
/// log's `.default` lines are not reliably persisted on every Mac, so each drop
/// also appends one line to a small file — counts and pasteboard types only,
/// never file paths — so an incident can still be reconstructed afterwards.
public enum DropJournalRules {

    /// One journal line. Mirrors the unified-log summary field for field.
    public static func line(timestamp: String, entry: String, branch: String,
                            requested: Int, resolved: Int, unreadable: Int, musicIDs: Int,
                            types: String) -> String {
        "\(timestamp) entry=\(entry) branch=\(branch) requested=\(requested) resolved=\(resolved) "
            + "unreadable=\(unreadable) musicIDs=\(musicIDs) types=\(types)"
    }

    /// Keeps the journal bounded: unchanged while at or under `maxBytes`,
    /// otherwise cut down to roughly half the cap, from the front, at a line
    /// boundary — the newest lines always survive. A single line longer than
    /// the cap keeps only its tail.
    public static func trimmedToTail(_ text: String, maxBytes: Int) -> String {
        let bytes = Array(text.utf8)
        guard bytes.count > maxBytes else { return text }
        let keep = max(1, maxBytes / 2)
        var start = bytes.count - keep
        if let newline = bytes[start...].firstIndex(of: 0x0A), newline + 1 < bytes.count {
            start = newline + 1
        }
        return String(decoding: bytes[start...], as: UTF8.self)
    }
}
