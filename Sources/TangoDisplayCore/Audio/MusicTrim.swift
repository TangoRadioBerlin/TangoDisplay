import Foundation

/// Converts Music's per-track start/stop (Song Info → Options), given in milliseconds,
/// into playback-trim seconds. Music reports `startMs == 0` and `stopMs == 0`-or-`totalMs`
/// when the checkboxes are off, so those map to `nil` (no trim on that end).
public func musicTrimSeconds(startMs: Int, stopMs: Int, totalMs: Int) -> (start: Double?, end: Double?) {
    let start = startMs > 0 ? Double(startMs) / 1000 : nil
    let end   = (stopMs > 0 && stopMs < totalMs) ? Double(stopMs) / 1000 : nil
    return (start, end)
}

/// Which trim start applies when a track loads. A manual entry trim always
/// wins; otherwise the Music start time applies to every track — cortinas
/// unconditionally, dance tracks unless the entry opted out. nil = start at
/// the file beginning.
public func effectiveTrimStart(entryTrimStart: Double?, musicStart: Double?,
                               isCortina: Bool, ignoresMusicStart: Bool) -> Double? {
    if let entryTrimStart { return entryTrimStart }
    if !isCortina && ignoresMusicStart { return nil }
    return musicStart
}

/// Row marker for the Music start time. `.none` when nothing Music-related is
/// visible: no Music start, or a manual trim that overrides it (the trim badge
/// shows instead).
public enum MusicStartBadge: Equatable {
    case none
    case active(seconds: Double)
    case ignored(seconds: Double)
}

public func musicStartBadge(entryTrimStart: Double?, musicStart: Double?,
                            isCortina: Bool, ignoresMusicStart: Bool) -> MusicStartBadge {
    guard entryTrimStart == nil, let musicStart else { return .none }
    if !isCortina && ignoresMusicStart { return .ignored(seconds: musicStart) }
    return .active(seconds: musicStart)
}

/// Music's persistent IDs for the tracks in a drag, read from the metadata plist Music puts
/// on the pasteboard (`com.apple.tv.metadata` / the legacy `'itun'` flavor). That plist gives
/// `Location` and `Persistent ID` but *not* the start/stop times, so the ID is what lets us
/// look the times up without the ~4s cost of asking ITLibrary for every track's location.
///
/// The filename fallback covers file-promise drops, where Music materialises a copy into our
/// app-support cache and the dropped URL's full path never matches the library's.
public struct MusicDragIDs {
    private var byPath: [String: String] = [:]
    private var byName: [String: String] = [:]

    public init() {}

    /// Accepts both plist shapes Music has used: `{"Tracks": {id: {...}}}` and a bare `{id: {...}}`.
    /// Keys are Unicode-normalised (NFC) — the plist location and a resolved drop URL can
    /// disagree on umlaut composition. A basename shared by two different tracks in the same
    /// drag disables the filename fallback for that name: guessing would import the wrong
    /// track's times and persist the wrong ID.
    public init(musicMetadataPlist plist: [String: Any]) {
        let tracks = (plist["Tracks"] as? [String: Any]) ?? plist
        var ambiguousNames = Set<String>()
        for (_, value) in tracks {
            guard let track = value as? [String: Any],
                  let persistentID = track["Persistent ID"] as? String,
                  let location = track["Location"] as? String,
                  let rawPath = MusicDragIDs.path(fromLocation: location)
            else { continue }
            let path = MusicDragIDs.key(rawPath)
            byPath[path] = persistentID
            let name = (path as NSString).lastPathComponent
            if ambiguousNames.contains(name) { continue }
            if byName[name] != nil && byName[name] != persistentID {
                byName[name] = nil
                ambiguousNames.insert(name)
            } else {
                byName[name] = persistentID
            }
        }
    }

    private static func key(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping
    }

    /// `Location` is either a "file://…" URL or a "~/…" tilde path, depending on Music version.
    /// `file:` strings go through the strict pasteboard parser — `URL(string:)` silently
    /// truncates unencoded `#`/`?` in filenames.
    static func path(fromLocation location: String) -> String? {
        guard !location.isEmpty else { return nil }
        if location.hasPrefix("file:") {
            guard let url = DropPasteboardRules.fileURL(fromPasteboardString: location) else { return nil }
            return url.path
        }
        return (location as NSString).expandingTildeInPath
    }

    public var isEmpty: Bool { byPath.isEmpty }
    public var count: Int { byPath.count }

    /// nil means this URL wasn't part of a Music drag — no trim import for it.
    public func persistentID(for url: URL) -> String? {
        let path = MusicDragIDs.key(url.path)
        return byPath[path] ?? byName[(path as NSString).lastPathComponent]
    }

    /// The same IDs without the filename fallback. The fallback exists for
    /// materialised promise copies (different path, same basename), which only
    /// window-level drops produce; a row drop reads a drag pasteboard that may
    /// belong to an earlier drag, where a basename match would pin another
    /// track's ID onto the dropped file. An exact path hit is correct either way.
    public func exactPathsOnly() -> MusicDragIDs {
        var copy = self
        copy.byName = [:]
        return copy
    }
}
