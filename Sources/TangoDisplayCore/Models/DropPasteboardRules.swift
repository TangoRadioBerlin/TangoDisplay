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

    // MARK: - Resolution accounting

    /// Requested-vs-resolved bookkeeping for a drop. Any shortfall must reach
    /// the user — a silently truncated multi-track drag is the failure mode
    /// this exists to prevent.
    public enum ResolutionOutcome: Equatable {
        case nothingRequested
        case complete
        case partial(unreadable: Int)
        case empty(unreadable: Int)
    }

    public static func resolutionOutcome(requested: Int, resolved: Int) -> ResolutionOutcome {
        if requested <= 0 { return .nothingRequested }
        if resolved >= requested { return .complete }
        return resolved > 0 ? .partial(unreadable: requested - resolved)
                            : .empty(unreadable: requested)
    }

    /// Compact, deterministic histogram of per-item type sets for the
    /// persisted drop log — e.g. `3x[a+b] 1x[b]`. Groups keep first-seen
    /// order; types inside a group are sorted. Never contains file paths.
    public static func typeSummary(itemTypes: [Set<String>], maxItems: Int = 20) -> String {
        guard !itemTypes.isEmpty else { return "0 items" }
        var order: [String] = []
        var counts: [String: Int] = [:]
        for types in itemTypes {
            let key = types.sorted().joined(separator: "+")
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        var parts: [String] = []
        var shown = 0
        for key in order {
            if shown >= maxItems { break }
            parts.append("\(counts[key]!)x[\(key)]")
            shown += 1
        }
        if order.count > shown { parts.append("+\(order.count - shown) more") }
        return parts.joined(separator: " ")
    }

    /// Order-preserving de-duplication on standardized file URLs (a Music
    /// metadata plist may list the same track once per item).
    public static func dedupe(_ urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        var out: [URL] = []
        for url in urls {
            let key = url.standardizedFileURL
            if seen.insert(key).inserted { out.append(url) }
        }
        return out
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

    // MARK: - Music.app metadata plist

    /// Extract track file URLs from Music.app's `com.apple.music.metadata`
    /// plist. Two known shapes (varies by Music.app version):
    ///   Newer: {"Tracks": {"12345": {"Location": "…"}}, "Playlists": […]}
    ///   Older: {"12345": {"Location": "…"}, "Playlist Items": […]}
    /// `Location` is a `file://` URL or a `~/…` tilde path. `file:` strings go
    /// through `fileURL(fromPasteboardString:)` — never `URL(string:)`, which
    /// truncates unencoded `#`/`?`. Entries are ordered by numeric track key so
    /// the result is deterministic (dictionary iteration is not).
    public static func musicMetadataLocations(_ plist: [String: Any]) -> [URL] {
        let trackSource = (plist["Tracks"] as? [String: Any]) ?? plist
        let keys = trackSource.keys.sorted { a, b in
            switch (Int(a), Int(b)) {
            case let (x?, y?): return x < y
            case (nil, nil):   return a < b
            case (nil, _):     return false
            case (_, nil):     return true
            }
        }
        var urls: [URL] = []
        for key in keys {
            guard let track = trackSource[key] as? [String: Any],
                  let location = track["Location"] as? String,
                  !location.isEmpty else { continue }
            if location.hasPrefix("file:") {
                if let url = fileURL(fromPasteboardString: location) { urls.append(url) }
            } else {
                let path = NSString(string: location).expandingTildeInPath
                guard path.hasPrefix("/") else { continue }
                urls.append(URL(fileURLWithPath: path))
            }
        }
        return urls
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
