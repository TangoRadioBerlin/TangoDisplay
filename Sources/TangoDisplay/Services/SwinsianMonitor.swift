import AppKit
import Foundation
import TangoDisplayCore

/// Listens to Swinsian's NSDistributedNotificationCenter push notifications.
///
/// All observer blocks are registered to deliver on OperationQueue.main,
/// matching MusicPoller's contract that callbacks arrive on the main queue.
///
/// Playlist enumeration is unavailable, but look-ahead is supported via
/// Swinsian's `playback queue` AppleScript property. triggerPlaylistFetch()
/// fetches queue[2] (the track after current) and delivers it via onNextTrackUpdate.
/// Tanda position counting uses the history-based fallback (no backward-looking context
/// is available from a queue that starts at the current track).
final class SwinsianMonitor: @unchecked Sendable {

    private static let notifyPlaying = "com.swinsian.Swinsian-Track-Playing"
    private static let notifyPaused  = "com.swinsian.Swinsian-Track-Paused"
    private static let notifyStopped = "com.swinsian.Swinsian-Track-Stopped"

    // MARK: - MusicPlayerSource callbacks

    var onTrackUpdate: ((Track?, PlayerState) -> Void)?
    var onPlaylistUpdate: ((tracks: [Track], currentIndex: Int)?) -> Void = { _ in }
    var onNextTrackUpdate: ((Track?) -> Void)? = nil
    var onWatchdogChanged: ((Bool) -> Void)?

    private var observers: [AnyObject] = []

    // MARK: - AppleScript helpers

    private static let artworkPathScript = """
        tell application "Swinsian"
            try
                if player state is not stopped then
                    return location of current track
                end if
            end try
            return ""
        end tell
        """

    // Returns three lines: comment (line 1), album artist (line 2), grouping (line 3) for the current track.
    private static let trackDetailsScript = """
        tell application "Swinsian"
            try
                if player state is not stopped then
                    set t to current track
                    set c to comment of t
                    if c is missing value then set c to ""
                    set aa to ""
                    try
                        set aa to album artist of t
                        if aa is missing value then set aa to ""
                    end try
                    set grp to ""
                    try
                        set grp to grouping of t
                        if grp is missing value then set grp to ""
                    end try
                    return c & linefeed & aa & linefeed & grp
                end if
            end try
            return linefeed & linefeed
        end tell
        """

    // Returns field-separated data for the second track in the playback queue (the
    // track that will play after the current one), or empty string if the queue has
    // fewer than two tracks. Fields: name, artist, genre, id, year, comment, albumArtist, grouping.
    private static let nextQueueTrackScript = """
        tell application "Swinsian"
            try
                tell playback queue
                    if (count of tracks) < 2 then return ""
                    set t to track 2
                    set fsep to (ASCII character 31)
                    set yr to year of t
                    set c to comment of t
                    if c is missing value then set c to ""
                    set aa to ""
                    try
                        set aa to album artist of t
                        if aa is missing value then set aa to ""
                    end try
                    set grp to ""
                    try
                        set grp to grouping of t
                        if grp is missing value then set grp to ""
                    end try
                    return (name of t) & fsep & (artist of t) & fsep & (genre of t) & fsep & (id of t) & fsep & (yr as text) & fsep & c & fsep & aa & fsep & grp
                end tell
            end try
            return ""
        end tell
        """

    private func runOsascript(_ script: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        // Bound the parse: a runaway/compromised player app returning a huge stdout
        // must not be turned into an even larger String (F4).
        guard ExternalInputLimits.isWithinLimit(data.count) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Lifecycle

    func start() {
        onWatchdogChanged?(false)   // clear any stale watchdog state from previous source

        let nc = DistributedNotificationCenter.default()

        let playingObs = nc.addObserver(
            forName: NSNotification.Name(Self.notifyPlaying),
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handlePlaying(userInfo: note.userInfo)
        }

        let pausedObs = nc.addObserver(
            forName: NSNotification.Name(Self.notifyPaused),
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handlePaused(userInfo: note.userInfo)
        }

        let stoppedObs = nc.addObserver(
            forName: NSNotification.Name(Self.notifyStopped),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onTrackUpdate?(nil, .stopped)
        }

        observers = [playingObs, pausedObs, stoppedObs]
    }

    func stop() {
        let nc = DistributedNotificationCenter.default()
        observers.forEach { nc.removeObserver($0) }
        observers.removeAll()
    }

    // MARK: - Notification handlers

    private func handlePlaying(userInfo: [AnyHashable: Any]?) {
        guard let track = parseTrack(from: userInfo) else {
            onTrackUpdate?(nil, .stopped)
            return
        }
        onTrackUpdate?(track, .playing)
        if track.comment == nil || track.albumArtist == nil || track.grouping == nil {
            fetchDetailsAndUpdate(baseTrack: track, state: .playing)
        }
        fetchAndNotifyNextTrack()
    }

    private func handlePaused(userInfo: [AnyHashable: Any]?) {
        guard let track = parseTrack(from: userInfo) else {
            onTrackUpdate?(nil, .stopped)
            return
        }
        onTrackUpdate?(track, .paused)
        if track.comment == nil || track.albumArtist == nil || track.grouping == nil {
            fetchDetailsAndUpdate(baseTrack: track, state: .paused)
        }
    }

    private func parseTrack(from userInfo: [AnyHashable: Any]?) -> Track? {
        guard let info = userInfo,
              let uuid = info["track_uuid"] as? String,
              !uuid.isEmpty
        else { return nil }

        let title      = info["title"]   as? String ?? ""
        let artist     = info["artist"]  as? String ?? ""
        let genre      = info["genre"]   as? String ?? ""
        let yearRaw    = (info["year"] as? NSNumber)?.intValue
                      ?? Int(info["year"] as? String ?? "")
                      ?? 0
        let year       = yearRaw > 0 ? yearRaw : nil
        let commentRaw  = info["comment"]  as? String ?? ""
        let comment     = commentRaw.isEmpty  ? nil : commentRaw
        let groupingRaw = info["grouping"] as? String ?? ""
        let grouping    = groupingRaw.isEmpty ? nil : groupingRaw
        return Track(title: title, artist: artist, genre: genre, persistentID: uuid, year: year, comment: comment, grouping: grouping)
    }

    private func fetchDetailsAndUpdate(baseTrack: Track, state: PlayerState) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let raw = self.runOsascript(Self.trackDetailsScript) ?? "\n"
            let lines = raw.components(separatedBy: "\n")
            let comment     = lines.count > 0 ? lines[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let albumArtist = lines.count > 1 ? lines[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let grouping    = lines.count > 2 ? lines[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let updated = Track(
                title: baseTrack.title, artist: baseTrack.artist,
                genre: baseTrack.genre, persistentID: baseTrack.persistentID,
                year: baseTrack.year,
                comment:     comment.isEmpty     ? baseTrack.comment     : comment,
                albumArtist: albumArtist.isEmpty ? baseTrack.albumArtist : albumArtist,
                grouping:    grouping.isEmpty    ? baseTrack.grouping    : grouping
            )
            DispatchQueue.main.async { [weak self] in
                self?.onTrackUpdate?(updated, state)
            }
        }
    }

    func fetchAndNotifyNextTrack() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let raw = (self.runOsascript(Self.nextQueueTrackScript) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let track = Self.parseQueueTrack(raw)
            DispatchQueue.main.async { [weak self] in
                self?.onNextTrackUpdate?(track)
            }
        }
    }

    private static func parseQueueTrack(_ raw: String) -> Track? {
        guard !raw.isEmpty else { return nil }
        let sep = String(UnicodeScalar(31)!)   // ASCII unit separator
        let fields = raw.components(separatedBy: sep)
        guard fields.count == 8 else { return nil }
        let title       = fields[0]
        let artist      = fields[1]
        let genre       = fields[2]
        let pid         = fields[3]
        let year        = Int(fields[4])
        let comment     = fields[5].isEmpty ? nil : fields[5]
        let albumArtist = fields[6].isEmpty ? nil : fields[6]
        let grouping    = fields[7].isEmpty ? nil : fields[7]
        guard !title.isEmpty, !pid.isEmpty else { return nil }
        return Track(title: title, artist: artist, genre: genre,
                     persistentID: pid, year: year, comment: comment, albumArtist: albumArtist,
                     grouping: grouping)
    }
}

// MARK: - MusicPlayerSource conformance

extension SwinsianMonitor: MusicPlayerSource {
    var supportsPlaylist: Bool { false }
    func pollNow()              {}  // push model: no polling
    func triggerPlaylistFetch() { fetchAndNotifyNextTrack() }

    func fetchArtwork(for track: Track) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let path = self.runOsascript(Self.artworkPathScript) ?? ""
                continuation.resume(returning: artworkFromAudioFile(path))
            }
        }
    }
}
