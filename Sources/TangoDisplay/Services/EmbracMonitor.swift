import AppKit
import Foundation
import TangoDisplayCore

/// Monitors Embrace via a hybrid push+poll strategy.
///
/// Embrace's distributed notification `com.iccir.Embrace.playerUpdate` fires on
/// every track change and state change, so we use it to trigger an immediate poll
/// rather than waiting for the 2-second timer. The timer runs as a fallback for
/// initial state on app start, recovery after Embrace quits, and watchdog backoff.
///
/// AppleScript is executed via /usr/bin/osascript (Process) rather than
/// NSAppleScript to avoid per-call compilation overhead; TCC attributes the
/// subprocess's Apple Events to the parent app (TangoDisplay).
///
/// Full setlist enumeration is supported via the `tracks` noun of the Embrace
/// application, which returns the current setlist in order. triggerPlaylistFetch()
/// dispatches a playlist script run on demand; doPoll() also refreshes the playlist
/// every playlistRefreshInterval polls for robustness.
final class EmbracMonitor: @unchecked Sendable {

    private static let updateNotification = "com.iccir.Embrace.playerUpdate"

    private let scriptQueue = DispatchQueue(label: "com.tangodisplay.embrace", qos: .utility)

    private var timer: DispatchSourceTimer?
    private var notificationObserver: AnyObject?

    private var consecutiveFailures = 0
    private var currentInterval: TimeInterval = 2.0
    private let normalInterval: TimeInterval = 2.0
    private let maxInterval: TimeInterval = 30.0
    private let failuresBeforeWatchdog = 3

    private var pollCount = 0
    private let playlistRefreshInterval = 10   // refresh playlist every ~20s at 2s poll rate

    // MARK: - MusicPlayerSource callbacks (all delivered on main queue)

    var onTrackUpdate: ((Track?, PlayerState) -> Void)?
    var onPlaylistUpdate: ((tracks: [Track], currentIndex: Int)?) -> Void = { _ in }
    var onNextTrackUpdate: ((Track?) -> Void)?
    var onWatchdogChanged: ((Bool) -> Void)?

    // MARK: - AppleScript source

    /// Returns fifteen newline-delimited fields: state, title, artist, genre, id, year,
    /// comment, albumArtist, grouping, nextTitle, nextArtist, nextGenre, nextID, nextYear, nextAlbumArtist.
    /// Next-track fields are empty strings / "0" when there is no following track. Uses
    /// `player state as string` because Embrace's dictionary does not export `paused`
    /// as a named constant — comparing `player state is paused` throws -2753 at runtime.
    private static let trackScript = """
        tell application "Embrace"
            try
                set idx to current index
                if idx is 0 then
                    return "stopped" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "0" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "0" & linefeed & ""
                end if
                set t to track idx
                set theTitle to title of t
                set theArtist to artist of t
                if theArtist is missing value then set theArtist to ""
                set theGenre to genre of t
                if theGenre is missing value then set theGenre to ""
                set theID to id of t
                set theYear to year of t
                if theYear is missing value then set theYear to 0
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
                set stateStr to player state as string
                if stateStr is "stopped" then
                    return "stopped" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "0" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "0" & linefeed & ""
                end if
                set totalTracks to count of tracks
                set nextTitle to ""
                set nextArtist to ""
                set nextGenre to ""
                set nextID to ""
                set nextYear to 0
                set nextAlbumArtist to ""
                set nextGrouping to ""
                if idx < totalTracks then
                    try
                        set nt to track (idx + 1)
                        set nextTitle to title of nt
                        set nextArtist to artist of nt
                        if nextArtist is missing value then set nextArtist to ""
                        set nextGenre to genre of nt
                        if nextGenre is missing value then set nextGenre to ""
                        set nextID to id of nt
                        set nextYear to year of nt
                        if nextYear is missing value then set nextYear to 0
                        set nextAlbumArtist to album artist of nt
                        if nextAlbumArtist is missing value then set nextAlbumArtist to ""
                        try
                            set nextGrouping to grouping of nt
                            if nextGrouping is missing value then set nextGrouping to ""
                        end try
                    end try
                end if
                return stateStr & linefeed & theTitle & linefeed & theArtist & linefeed & theGenre & linefeed & theID & linefeed & theYear & linefeed & theComment & linefeed & theAlbumArtist & linefeed & theGrouping & linefeed & nextTitle & linefeed & nextArtist & linefeed & nextGenre & linefeed & nextID & linefeed & nextYear & linefeed & nextAlbumArtist & linefeed & nextGrouping
            on error
                return "stopped" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "0" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "" & linefeed & "0" & linefeed & ""
            end try
        end tell
        """

    /// Returns the full setlist as newline-delimited text.
    /// Line 0: current index (1-based), or "0" on stopped/error.
    /// Lines 1…N: eight lines per track — title, artist, genre, id, year, comment, albumArtist, grouping.
    private static let playlistScript = """
        tell application "Embrace"
            try
                set stateStr to player state as string
                if stateStr is "stopped" then
                    return "0"
                end if
                set idx to current index
                if idx is 0 then return "0"
                set allTracks to tracks
                set output to idx as string
                repeat with t in allTracks
                    set theTitle to title of t
                    set theArtist to artist of t
                    if theArtist is missing value then set theArtist to ""
                    set theGenre to genre of t
                    if theGenre is missing value then set theGenre to ""
                    set theID to id of t
                    set theYear to year of t
                    if theYear is missing value then set theYear to 0
                    set theComment to comment of t
                    if theComment is missing value then set theComment to ""
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
                    set output to output & linefeed & theTitle & linefeed & theArtist & linefeed & theGenre & linefeed & theID & linefeed & theYear & linefeed & theComment & linefeed & theAlbumArtist & linefeed & theGrouping
                end repeat
                return output
            on error
                return "0"
            end try
        end tell
        """

    // MARK: - Lifecycle

    func start() {
        onWatchdogChanged?(false)

        let observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(Self.updateNotification),
            object: nil,
            queue: nil   // delivered on whatever thread DNC chooses; we dispatch to scriptQueue
        ) { [weak self] _ in
            self?.notificationTriggeredPoll()
        }
        notificationObserver = observer

        schedulePoll(after: 0)
    }

    func stop() {
        timer?.cancel()
        timer = nil
        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            notificationObserver = nil
        }
    }

    // MARK: - Scheduling

    private func notificationTriggeredPoll() {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.doPoll()
        }
    }

    private func schedulePoll(after delay: TimeInterval) {
        let t = DispatchSource.makeTimerSource(queue: scriptQueue)
        t.schedule(deadline: .now() + delay)
        t.setEventHandler { [weak self] in self?.doPoll() }
        t.resume()
        timer?.cancel()   // release any previous source before replacing it
        timer = t
    }

    // MARK: - Polling

    private func doPoll() {
        // Must be called on scriptQueue
        if let output = runScript() {
            handleSuccess()
            pollCount += 1
            if pollCount % playlistRefreshInterval == 0 {
                doPlaylistFetch()
            }
            let result = parseOutput(output)
            DispatchQueue.main.async { [weak self] in
                // Fire next-track first so AppState.lastKnownNextTrack is set
                // before handleCortinaTrack reads it via onTrackUpdate.
                self?.onNextTrackUpdate?(result.1)
                self?.onTrackUpdate?(result.0, result.2)
            }
        } else {
            handleFailure()
            DispatchQueue.main.async { [weak self] in
                self?.onNextTrackUpdate?(nil)
                self?.onTrackUpdate?(nil, .stopped)
            }
        }
        schedulePoll(after: currentInterval)
    }

    // MARK: - Playlist fetch

    private func doPlaylistFetch() {
        guard let output = runPlaylistScript() else { return }
        let result = parsePlaylistOutput(output)
        DispatchQueue.main.async { [weak self] in
            self?.onPlaylistUpdate(result)
        }
    }

    private func runPlaylistScript() -> String? {
        runOsascript(Self.playlistScript)
    }

    private func parsePlaylistOutput(_ output: String) -> (tracks: [Track], currentIndex: Int)? {
        var lines = output.components(separatedBy: "\n")
        if lines.last?.isEmpty == true { lines.removeLast() }

        guard let firstLine = lines.first,
              let currentIndex = Int(firstLine.trimmingCharacters(in: .whitespaces)),
              currentIndex > 0 else { return nil }

        let trackLines = Array(lines.dropFirst())
        let trackCount = trackLines.count / 8
        guard trackCount > 0 else { return nil }

        var tracks: [Track] = []
        tracks.reserveCapacity(trackCount)
        for i in 0..<trackCount {
            let base = i * 8
            guard base + 7 < trackLines.count else { break }
            let pid             = trackLines[base + 3].trimmingCharacters(in: .whitespaces)
            let yearRaw         = Int(trackLines[base + 4].trimmingCharacters(in: .whitespaces)) ?? 0
            let commentRaw      = trackLines[base + 5]
            let comment         = commentRaw.isEmpty ? nil : commentRaw
            let albumArtistRaw  = trackLines[base + 6]
            let albumArtist     = albumArtistRaw.isEmpty ? nil : albumArtistRaw
            let groupingRaw     = trackLines[base + 7]
            let grouping        = groupingRaw.isEmpty ? nil : groupingRaw
            tracks.append(Track(
                title:        trackLines[base],
                artist:       trackLines[base + 1],
                genre:        trackLines[base + 2],
                persistentID: pid,
                year:         yearRaw > 0 ? yearRaw : nil,
                comment:      comment,
                albumArtist:  albumArtist,
                grouping:     grouping
            ))
        }

        guard currentIndex <= tracks.count else { return nil }
        return (tracks: tracks, currentIndex: currentIndex - 1)
    }

    // MARK: - Script execution

    /// Runs the AppleScript via /usr/bin/osascript and returns stdout, or nil on failure.
    /// Must be called on scriptQueue (it blocks until the subprocess exits).
    private func runScript() -> String? {
        runOsascript(Self.trackScript)
    }

    private func runOsascript(_ script: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError  = stderrPipe

        do {
            try proc.run()
        } catch {
            NSLog("TangoDisplay: Embrace osascript launch failed: %@", error.localizedDescription)
            return nil
        }

        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg  = String(data: errData, encoding: .utf8) ?? ""
            NSLog("TangoDisplay: Embrace osascript error (%d): %@",
                  proc.terminationStatus, errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
            return nil
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        // Bound the parse: a runaway/compromised player app returning a huge stdout
        // must not be turned into an even larger String (F4).
        guard ExternalInputLimits.isWithinLimit(data.count) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Output parsing

    /// Parses sixteen newline-delimited fields: state, title, artist, genre, id, year,
    /// comment, albumArtist, grouping, nextTitle, nextArtist, nextGenre, nextID, nextYear, nextAlbumArtist, nextGrouping.
    /// Returns (currentTrack, nextTrack, playerState).
    private func parseOutput(_ output: String) -> (Track?, Track?, PlayerState) {
        // osascript appends a trailing newline; split keeping empty strings to preserve indices
        let lines = output.components(separatedBy: "\n")

        let stateRaw = lines.count > 0 ? lines[0].trimmingCharacters(in: .whitespaces) : "stopped"
        let state    = PlayerState(rawValue: stateRaw) ?? .stopped

        guard state != .stopped else { return (nil, nil, .stopped) }

        let title           = lines.count > 1 ? lines[1] : ""
        let artist          = lines.count > 2 ? lines[2] : ""
        let genre           = lines.count > 3 ? lines[3] : ""
        let pid             = lines.count > 4 ? lines[4].trimmingCharacters(in: .whitespaces) : ""
        let yearRaw         = lines.count > 5 ? Int(lines[5].trimmingCharacters(in: .whitespaces)) ?? 0 : 0
        let year            = yearRaw > 0 ? yearRaw : nil
        let commentRaw      = lines.count > 6 ? lines[6] : ""
        let comment         = commentRaw.isEmpty ? nil : commentRaw
        let albumArtistRaw  = lines.count > 7 ? lines[7] : ""
        let albumArtist     = albumArtistRaw.isEmpty ? nil : albumArtistRaw
        let groupingRaw     = lines.count > 8 ? lines[8] : ""
        let grouping        = groupingRaw.isEmpty ? nil : groupingRaw

        guard !pid.isEmpty || !title.isEmpty else { return (nil, nil, .stopped) }

        let currentTrack = Track(title: title, artist: artist, genre: genre, persistentID: pid, year: year, comment: comment, albumArtist: albumArtist, grouping: grouping)

        let nextTitle          = lines.count > 9  ? lines[9] : ""
        let nextArtist         = lines.count > 10 ? lines[10] : ""
        let nextGenre          = lines.count > 11 ? lines[11] : ""
        let nextID             = lines.count > 12 ? lines[12].trimmingCharacters(in: .whitespaces) : ""
        let nextYearRaw        = lines.count > 13 ? Int(lines[13].trimmingCharacters(in: .whitespaces)) ?? 0 : 0
        let nextYear           = nextYearRaw > 0 ? nextYearRaw : nil
        let nextAlbumArtistRaw = lines.count > 14 ? lines[14] : ""
        let nextAlbumArtist    = nextAlbumArtistRaw.isEmpty ? nil : nextAlbumArtistRaw
        let nextGroupingRaw    = lines.count > 15 ? lines[15] : ""
        let nextGrouping       = nextGroupingRaw.isEmpty ? nil : nextGroupingRaw

        let nextTrack: Track? = nextID.isEmpty && nextTitle.isEmpty ? nil :
            Track(title: nextTitle, artist: nextArtist, genre: nextGenre, persistentID: nextID, year: nextYear, albumArtist: nextAlbumArtist, grouping: nextGrouping)

        return (currentTrack, nextTrack, state)
    }

    // MARK: - Watchdog

    private func handleSuccess() {
        let wasWatchdog = consecutiveFailures >= failuresBeforeWatchdog
        consecutiveFailures = 0
        currentInterval = normalInterval
        if wasWatchdog {
            DispatchQueue.main.async { [weak self] in self?.onWatchdogChanged?(false) }
        }
    }

    private func handleFailure() {
        consecutiveFailures += 1
        if consecutiveFailures == failuresBeforeWatchdog {
            DispatchQueue.main.async { [weak self] in self?.onWatchdogChanged?(true) }
        }
        if consecutiveFailures >= failuresBeforeWatchdog {
            currentInterval = min(currentInterval * 2, maxInterval)
        }
    }

    // MARK: - Artwork fetch (file path via osascript + AVFoundation)

    private static let artworkPathScript = """
        tell application "Embrace"
            try
                set idx to current index
                if idx is not 0 then
                    set f to file of track idx
                    tell application "Finder" to return POSIX path of f
                end if
            end try
            return ""
        end tell
        """
}

// MARK: - MusicPlayerSource conformance

extension EmbracMonitor: MusicPlayerSource {
    func pollNow() {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.doPoll()
        }
    }

    func triggerPlaylistFetch() {
        scriptQueue.async { [weak self] in self?.doPlaylistFetch() }
    }

    func fetchArtwork(for track: Track) async -> NSImage? {
        await withCheckedContinuation { continuation in
            scriptQueue.async { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let path = self.runOsascript(Self.artworkPathScript) ?? ""
                continuation.resume(returning: artworkFromAudioFile(path))
            }
        }
    }
}
