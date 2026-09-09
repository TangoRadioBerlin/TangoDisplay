import AppKit
import Foundation
import TangoDisplayCore

// MARK: - PlayerState

enum PlayerState: String, Equatable {
    case playing, pauseArmed, paused, stopped
}

// MARK: - AppleScriptBridge

/// Wraps NSAppleScript to read track and playlist data from Music.app.
///
/// Both scripts are compiled once at startup and reused, avoiding the fork
/// overhead of shelling out to osascript on every poll.
///
/// Thread safety: each fetch must run on `queue` (a dedicated serial background
/// queue). The two NSAppleScript instances are never shared across threads.
final class AppleScriptBridge {

    private let queue = DispatchQueue(label: "com.tangodisplay.applescript", qos: .utility)

    /// Returns list: [name, artist, genre, persistentID, year, playerStateString, comment, albumArtist, grouping]
    private static let trackScriptSource = """
        tell application "Music"
            try
                if player state is playing then
                    set t to current track
                    set theComment to ""
                    try
                        set theComment to comment of t
                        if theComment is missing value then set theComment to ""
                    end try
                    set theAlbumArtist to ""
                    try
                        set theAlbumArtist to album artist of t
                        if theAlbumArtist is missing value then set theAlbumArtist to ""
                    end try
                    set theGrouping to ""
                    try
                        set theGrouping to grouping of t
                        if theGrouping is missing value then set theGrouping to ""
                    end try
                    return {name of t, artist of t, genre of t, persistent ID of t, year of t, "playing", theComment, theAlbumArtist, theGrouping}
                else if player state is paused then
                    set t to current track
                    set theComment to ""
                    try
                        set theComment to comment of t
                        if theComment is missing value then set theComment to ""
                    end try
                    set theAlbumArtist to ""
                    try
                        set theAlbumArtist to album artist of t
                        if theAlbumArtist is missing value then set theAlbumArtist to ""
                    end try
                    set theGrouping to ""
                    try
                        set theGrouping to grouping of t
                        if theGrouping is missing value then set theGrouping to ""
                    end try
                    return {name of t, artist of t, genre of t, persistent ID of t, year of t, "paused", theComment, theAlbumArtist, theGrouping}
                else
                    return {"", "", "", "", 0, "stopped", "", "", ""}
                end if
            on error
                return {"", "", "", "", 0, "stopped", "", "", ""}
            end try
        end tell
        """

    /// Returns list: [currentIndex (1-based), [[name, artist, genre, persistentID], ...]]
    /// currentIndex is 0 if unavailable (not in a fixed playlist or on error).
    private static let playlistScriptSource = """
        tell application "Music"
            try
                if player state is stopped then
                    return {0, {}}
                end if
                set pl to current playlist
                set currentTrackID to persistent ID of current track
                set allTracks to tracks of pl
                set trackList to {}
                set foundIndex to 0
                set i to 0
                repeat with t in allTracks
                    set i to i + 1
                    set theComment to comment of t
                    if theComment is missing value then set theComment to ""
                    set theAlbumArtist to album artist of t
                    if theAlbumArtist is missing value then set theAlbumArtist to ""
                    set theGrouping to ""
                    try
                        set theGrouping to grouping of t
                        if theGrouping is missing value then set theGrouping to ""
                    end try
                    set trackList to trackList & {{name of t, artist of t, genre of t, persistent ID of t, year of t, theComment, theAlbumArtist, theGrouping}}
                    if persistent ID of t is currentTrackID then
                        set foundIndex to i
                    end if
                end repeat
                return {foundIndex, trackList}
            on error
                return {0, {}}
            end try
        end tell
        """

    /// Returns raw image bytes of the current track's first artwork, or "" when none.
    private static let artworkScriptSource = """
        tell application "Music"
            try
                if player state is not stopped then
                    if (count artworks of current track) > 0 then
                        return raw data of artwork 1 of current track
                    end if
                end if
            end try
            return ""
        end tell
        """

    private var trackScript: NSAppleScript?
    private var playlistScript: NSAppleScript?
    private var artworkScript: NSAppleScript?

    // MARK: - Lifecycle

    /// Compile both scripts. Call once at startup (on any thread; dispatches to serial queue).
    func compile() {
        queue.async { [weak self] in
            guard let self else { return }
            var err: NSDictionary?

            self.trackScript = NSAppleScript(source: Self.trackScriptSource)
            self.trackScript?.compileAndReturnError(&err)
            if let err { NSLog("TangoDisplay: trackScript compile error: %@", err) }

            self.playlistScript = NSAppleScript(source: Self.playlistScriptSource)
            self.playlistScript?.compileAndReturnError(&err)
            if let err { NSLog("TangoDisplay: playlistScript compile error: %@", err) }

            self.artworkScript = NSAppleScript(source: Self.artworkScriptSource)
            self.artworkScript?.compileAndReturnError(&err)
            if let err { NSLog("TangoDisplay: artworkScript compile error: %@", err) }
        }
    }

    // MARK: - Fetch current track

    /// Returns the current track and player state.
    /// Throws on AppleScript execution error (e.g. Music.app not running).
    /// Must NOT be called from the main thread — dispatches on `queue` internally.
    func fetchCurrentTrack(completion: @escaping (Result<(Track?, PlayerState), Error>) -> Void) {
        queue.async { [weak self] in
            // Must still call completion when self is already gone — MusicPoller's
            // reschedule chain lives in this callback; silently dropping it here
            // stalls polling until something else (a notification) kicks it again.
            guard let self else {
                completion(.failure(NSError(domain: "TangoDisplay", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "AppleScriptBridge deallocated"])))
                return
            }
            var errorInfo: NSDictionary?
            guard let script = self.trackScript else {
                completion(.failure(NSError(domain: "TangoDisplay", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Track script not compiled"])))
                return
            }
            let descriptor = script.executeAndReturnError(&errorInfo)
            guard errorInfo == nil else {
                let err = NSError(domain: "TangoDisplay", code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        errorInfo?[NSAppleScript.errorMessage] as? String
                        ?? "AppleScript execution failed"])
                completion(.failure(err))
                return
            }

            let result = Self.parseTrackDescriptor(descriptor)
            completion(.success(result))
        }
    }

    // MARK: - Fetch playlist context

    /// Returns ordered playlist tracks and current index (1-based), or nil if
    /// Music.app is not playing from a fixed playlist (shuffle, library view, etc.).
    func fetchPlaylistContext(completion: @escaping (Result<(tracks: [Track], currentIndex: Int)?, Error>) -> Void) {
        queue.async { [weak self] in
            // See fetchCurrentTrack: completion must still fire when self is gone.
            guard let self else {
                completion(.failure(NSError(domain: "TangoDisplay", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "AppleScriptBridge deallocated"])))
                return
            }
            var errorInfo: NSDictionary?
            guard let script = self.playlistScript else {
                completion(.failure(NSError(domain: "TangoDisplay", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Playlist script not compiled"])))
                return
            }
            let descriptor = script.executeAndReturnError(&errorInfo)
            guard errorInfo == nil else {
                let err = NSError(domain: "TangoDisplay", code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        errorInfo?[NSAppleScript.errorMessage] as? String
                        ?? "Playlist AppleScript failed"])
                completion(.failure(err))
                return
            }

            let result = Self.parsePlaylistDescriptor(descriptor)
            completion(.success(result))
        }
    }

    // MARK: - Fetch album artwork

    /// Returns the artwork image for the current track, or nil when unavailable.
    /// Must NOT be called from the main thread — dispatches on `queue` internally.
    func fetchCurrentArtwork(completion: @escaping (NSImage?) -> Void) {
        queue.async { [weak self] in
            guard let self, let script = self.artworkScript else {
                completion(nil)
                return
            }
            var errorInfo: NSDictionary?
            let descriptor = script.executeAndReturnError(&errorInfo)
            if let errorInfo {
                NSLog("TangoDisplay: artwork fetch error: %@", errorInfo)
                completion(nil)
                return
            }
            // descriptor.data returns raw bytes when artwork is present, or an
            // empty/string-encoded value when the script returns "". NSImage(data:)
            // returns nil for non-image bytes, so we rely on that to filter.
            completion(NSImage(data: descriptor.data))
        }
    }

    // MARK: - Descriptor parsing

    /// Parses a list descriptor: [name, artist, genre, persistentID, year, stateString, comment]
    private static func parseTrackDescriptor(_ d: NSAppleEventDescriptor) -> (Track?, PlayerState) {
        let stateRaw = d.atIndex(6)?.stringValue ?? "stopped"
        let state = PlayerState(rawValue: stateRaw) ?? .stopped

        if state == .stopped {
            return (nil, .stopped)
        }

        let title   = d.atIndex(1)?.stringValue ?? ""
        let artist  = d.atIndex(2)?.stringValue ?? ""
        let genre   = d.atIndex(3)?.stringValue ?? ""
        let pid     = d.atIndex(4)?.stringValue ?? ""
        let yearRaw = d.atIndex(5)?.int32Value ?? 0
        let year    = yearRaw > 0 ? Int(yearRaw) : nil
        let commentRaw     = d.atIndex(7)?.stringValue ?? ""
        let comment        = commentRaw.isEmpty ? nil : commentRaw
        let albumArtistRaw = d.atIndex(8)?.stringValue ?? ""
        let albumArtist    = albumArtistRaw.isEmpty ? nil : albumArtistRaw
        let groupingRaw    = d.atIndex(9)?.stringValue ?? ""
        let grouping       = groupingRaw.isEmpty ? nil : groupingRaw

        if pid.isEmpty && title.isEmpty {
            return (nil, .stopped)
        }

        return (Track(title: title, artist: artist, genre: genre, persistentID: pid, year: year, comment: comment, albumArtist: albumArtist, grouping: grouping), state)
    }

    /// Parses: {currentIndex (int), [[name, artist, genre, pid, year, comment], ...]}
    private static func parsePlaylistDescriptor(_ d: NSAppleEventDescriptor) -> (tracks: [Track], currentIndex: Int)? {
        let currentIndex = d.atIndex(1).map { Int($0.int32Value) } ?? 0
        guard currentIndex > 0 else { return nil }

        guard let trackList = d.atIndex(2) else { return nil }
        let count = trackList.numberOfItems
        guard count > 0 else { return nil }

        var tracks: [Track] = []
        tracks.reserveCapacity(count)

        for i in 1...count {
            guard let item = trackList.atIndex(i) else { continue }
            let title      = item.atIndex(1)?.stringValue ?? ""
            let artist     = item.atIndex(2)?.stringValue ?? ""
            let genre      = item.atIndex(3)?.stringValue ?? ""
            let pid        = item.atIndex(4)?.stringValue ?? ""
            let yearRaw    = item.atIndex(5)?.int32Value ?? 0
            let year       = yearRaw > 0 ? Int(yearRaw) : nil
            let commentRaw     = item.atIndex(6)?.stringValue ?? ""
            let comment        = commentRaw.isEmpty ? nil : commentRaw
            let albumArtistRaw = item.atIndex(7)?.stringValue ?? ""
            let albumArtist    = albumArtistRaw.isEmpty ? nil : albumArtistRaw
            let groupingRaw    = item.atIndex(8)?.stringValue ?? ""
            let grouping       = groupingRaw.isEmpty ? nil : groupingRaw
            tracks.append(Track(title: title, artist: artist, genre: genre, persistentID: pid, year: year, comment: comment, albumArtist: albumArtist, grouping: grouping))
        }

        // Bounds-check: 1-based AppleScript index must fit the array
        guard currentIndex <= tracks.count else { return nil }

        return (tracks: tracks, currentIndex: currentIndex - 1) // convert to 0-based
    }
}

// MARK: - Setlist export

/// Creates a new user playlist in Music.app and adds each file URL to it.
/// Runs the AppleScript on a background queue; calls `completion` on the main queue.
func createAppleMusicPlaylist(
    name: String,
    fileURLs: [URL],
    completion: @escaping (Result<Void, Error>) -> Void
) {
    DispatchQueue.global(qos: .utility).async {
        func escaped(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }

        let addLines = fileURLs
            .map { "            add POSIX file \"\(escaped($0.path))\" to thePlaylist" }
            .joined(separator: "\n")

        let source = """
            tell application "Music"
                try
                    set thePlaylist to make new user playlist with properties {name: "\(escaped(name))"}
            \(addLines)
                    return "ok"
                on error errMsg
                    return "error:" & errMsg
                end try
            end tell
            """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "TangoDisplay", code: 10,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create AppleScript"])))
            }
            return
        }
        let result = script.executeAndReturnError(&errorInfo)

        DispatchQueue.main.async {
            if let errorInfo {
                let msg = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                completion(.failure(NSError(domain: "TangoDisplay", code: 10,
                    userInfo: [NSLocalizedDescriptionKey: msg])))
                return
            }
            let returnVal = result.stringValue ?? ""
            if returnVal.hasPrefix("error:") {
                completion(.failure(NSError(domain: "TangoDisplay", code: 11,
                    userInfo: [NSLocalizedDescriptionKey: String(returnVal.dropFirst(6))])))
            } else {
                completion(.success(()))
            }
        }
    }
}
