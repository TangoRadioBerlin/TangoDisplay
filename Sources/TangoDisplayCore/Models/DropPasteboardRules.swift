import Foundation

/// Pasteboard type identifiers seen on Music.app / Finder / player drags, as
/// plain strings (AppKit wraps them in `NSPasteboard.PasteboardType`).
public enum DropPasteboardType {
    /// Legacy Music.app drag marker (pre-Sequoia / older purchased AAC).
    public static let itunesDrag = "com.apple.itunes.drag"
    /// Music.app plist with per-track "Location" entries.
    public static let musicMetadata = "com.apple.music.metadata"
    /// Music.app on Sequoia for iTunes-purchased AAC.
    public static let musicJRFS = "com.apple.Music.JRFS"
    /// Legacy file-promise flavors (Music.app's actual mechanism on Sequoia).
    public static let legacyPromiseURL = "com.apple.pasteboard.promised-file-url"
    public static let legacyPromiseContents = "NSPromiseContentsPboardType"
    /// Plain file URL (Finder, Swinsian, foobar2000, AIFF-from-Music).
    public static let fileURL = "public.file-url"
}

/// Which branch of the drop resolver a pasteboard payload takes. Ordered by
/// the resolver's priority (promise flavors first, AppleScript selection last).
public enum DropPayloadKind: String, Equatable {
    case modernFilePromise, legacyFilePromise, musicMetadata, fileURL, musicSelection, unsupported
}

/// Pure rules for resolving drag-pasteboard payloads into file URLs and for
/// deciding how the legacy file-promise drop path may proceed.
/// Kept in Core so the logic is unit-testable without AppKit.
public enum DropPasteboardRules {

    // MARK: - Payload classification

    /// Classify a multi-item pasteboard by the UNION of every item's types —
    /// Music.app selections are heterogeneous (only some items carry the
    /// promise string, others just a file-url), and the branch must be chosen
    /// for the whole drag, never per item. Priority mirrors the resolver:
    /// modern promise → legacy promise → Music metadata → file-url → Music
    /// selection (AppleScript) → unsupported. `modernPromiseTypes` is injected
    /// because `NSFilePromiseReceiver.readableDraggedTypes` lives in AppKit.
    public static func classify(itemTypes: [Set<String>],
                                modernPromiseTypes: Set<String>) -> DropPayloadKind {
        let union = itemTypes.reduce(into: Set<String>()) { $0.formUnion($1) }
        if !union.isDisjoint(with: modernPromiseTypes) { return .modernFilePromise }
        if union.contains(DropPasteboardType.legacyPromiseURL)
            || union.contains(DropPasteboardType.legacyPromiseContents) { return .legacyFilePromise }
        if union.contains(DropPasteboardType.musicMetadata) { return .musicMetadata }
        if union.contains(DropPasteboardType.fileURL) { return .fileURL }
        if union.contains(DropPasteboardType.itunesDrag) { return .musicSelection }
        return .unsupported
    }

    /// Music.app-specific flavors on ANY item identify the only source whose
    /// file promises the resolver may materialise synchronously.
    public static func isMusicAppSource(itemTypes: [Set<String>]) -> Bool {
        itemTypes.contains { types in
            types.contains(DropPasteboardType.itunesDrag)
                || types.contains(DropPasteboardType.musicMetadata)
                || types.contains(DropPasteboardType.musicJRFS)
        }
    }

    // MARK: - Pasteboard string → file URL

    /// Parse a pasteboard string into a local file URL.
    ///
    /// Accepts three shapes seen in the wild:
    ///   - well-formed `file://` URLs (percent-encoded, optional `localhost` host),
    ///   - `file://` strings with unencoded characters (some players skip encoding),
    ///   - bare absolute POSIX paths (foobar2000 writes `public.file-url` this way).
    ///
    /// `file://` strings are parsed manually, never via `URL(string:)`: modern
    /// Foundation parses leniently and reinterprets unencoded `#`/`?` as
    /// fragment/query — silently truncating the path while `isFileURL` stays
    /// true ("Milonga #2.mp3" → "Milonga "). The host is normalised away
    /// (`file://localhost/...` must compare equal to a plain path URL for
    /// duplicate detection); any other host yields nil.
    ///
    /// Anything else (relative paths, non-file schemes, empty) yields nil.
    public static func fileURL(fromPasteboardString string: String) -> URL? {
        guard !string.isEmpty else { return nil }
        if string.hasPrefix("file://") {
            let rest = String(string.dropFirst("file://".count))
            guard let slash = rest.firstIndex(of: "/") else { return nil }
            let host = String(rest[..<slash])
            guard host.isEmpty || host == "localhost" else { return nil }
            let rawPath = String(rest[slash...])
            // Decode percent-encoding when present; a literal "%" that is not a
            // valid escape makes decoding fail — keep the raw path then.
            let path = rawPath.removingPercentEncoding ?? rawPath
            return URL(fileURLWithPath: path)
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
