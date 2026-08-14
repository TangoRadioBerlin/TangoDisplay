import Foundation

/// Pure rules for resolving drag-pasteboard payloads into file URLs and for
/// deciding how the legacy file-promise drop path may proceed.
/// Kept in Core so the logic is unit-testable without AppKit.
public enum DropPasteboardRules {

    // MARK: - Pasteboard string → file URL

    /// Parse a pasteboard string into a local file URL.
    ///
    /// Accepts three shapes seen in the wild:
    ///   - well-formed `file://` URLs (percent-encoded),
    ///   - `file://` strings with unencoded characters (some players skip
    ///     encoding; `URL(string:)` rejects those, so fall back to a path init),
    ///   - bare absolute POSIX paths (foobar2000 writes `public.file-url` this way).
    ///
    /// Anything else (relative paths, non-file schemes, empty) yields nil.
    public static func fileURL(fromPasteboardString string: String) -> URL? {
        guard !string.isEmpty else { return nil }
        if string.hasPrefix("file://") {
            if let url = URL(string: string), url.isFileURL, !url.path.isEmpty {
                return url
            }
            // Unencoded characters — strip the scheme and treat the rest as a path.
            let raw = String(string.dropFirst("file://".count))
            guard raw.hasPrefix("/") else { return nil }
            return URL(fileURLWithPath: raw)
        }
        if string.hasPrefix("/") {
            return URL(fileURLWithPath: string)
        }
        return nil
    }

    // MARK: - Legacy file-promise decision

    /// How the legacy file-promise drop path should proceed after per-item
    /// URL resolution.
    public enum LegacyPromiseAction: Equatable {
        /// Every advertised item resolved to an on-disk file — use them directly.
        case acceptResolved
        /// Ask the source app to write the promised files (synchronous, blocks
        /// the drop callout) — permitted for Music.app cloud-only tracks only.
        case materialize
        /// Use the subset that resolved; never block on a non-Music source.
        case acceptPartial
        /// Nothing resolved and materialization is not permitted — reject the drop.
        case fail
    }

    /// Decide the legacy-promise action.
    ///
    /// `resolved` is the number of items that resolved to on-disk files,
    /// `advertised` the number of items advertising a file flavor, and
    /// `isMusicAppSource` whether the drag carries Music.app-specific flavors.
    ///
    /// Synchronous materialization (`namesOfPromisedFilesDropped`) makes the
    /// destination wait inside the drop callout while the source app writes
    /// files — if the source is itself blocked in its drag loop awaiting our
    /// drop reply, the two processes deadlock. Music.app is the only source
    /// that needs it (cloud-only tracks with no on-disk file), so it is the
    /// only source allowed to trigger it.
    public static func legacyPromiseAction(
        resolved: Int,
        advertised: Int,
        isMusicAppSource: Bool
    ) -> LegacyPromiseAction {
        if resolved > 0 && resolved >= advertised { return .acceptResolved }
        if isMusicAppSource { return .materialize }
        return resolved > 0 ? .acceptPartial : .fail
    }
}
