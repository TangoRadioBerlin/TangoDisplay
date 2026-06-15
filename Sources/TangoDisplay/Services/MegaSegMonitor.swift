import AppKit
import Foundation
import TangoDisplayCore

/// Monitors MegaSeg via a hybrid push+poll strategy.
///
/// MegaSeg's distributed notification `com.fidelitymedia.MegaSeg.nowPlaying` fires on
/// every track change, triggering an immediate poll rather than waiting for the 2-second
/// timer. The timer provides initial state on start, recovery after MegaSeg quits, and
/// watchdog backoff.
///
/// No AppleScript is available — MegaSeg's SDEF only exposes control commands, not
/// property access. Instead we read the log files MegaSeg writes to ~/Music/MegaSeg/Logs/:
///   NowPlaying.txt   current track (single line, Program deck only)
///   ComingUp.html    upcoming tracks for playlist lookahead
///   NowPlaying.jpg   artwork for the current track
///
/// The pre-listen/cue deck does NOT update NowPlaying.txt or fire the distributed
/// notification — only the main Program output (what the audience hears) is reflected.
/// Requires MegaSeg v5.9.4+ for the distributed notification; older versions fall back
/// to 2-second polling only.
final class MegaSegMonitor: @unchecked Sendable {

    private static let nowPlayingNotification = "com.fidelitymedia.MegaSeg.nowPlaying"
    private static let bundleID = "com.fidelitymedia.MegaSeg"

    private static let logsDir: URL = {
        let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        return music.appendingPathComponent("MegaSeg/Logs", isDirectory: true)
    }()

    private static let libraryFile: URL = {
        let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        return music.appendingPathComponent("MegaSeg/Library/MegaSeg Database")
    }()

    private let fileQueue = DispatchQueue(label: "com.tangodisplay.megaseg", qos: .utility)

    private var genreByArtistTitle: [String: String] = [:]

    private var timer: DispatchSourceTimer?
    private var notificationObserver: AnyObject?

    private var consecutiveFailures = 0
    private var currentInterval: TimeInterval = 2.0
    private let normalInterval: TimeInterval = 2.0
    private let maxInterval: TimeInterval = 30.0
    private let failuresBeforeWatchdog = 3

    private var pollCount = 0
    private let playlistRefreshInterval = 10

    // MARK: - MusicPlayerSource callbacks (all delivered on main queue)

    var onTrackUpdate: ((Track?, PlayerState) -> Void)?
    var onPlaylistUpdate: ((tracks: [Track], currentIndex: Int)?) -> Void = { _ in }
    var onNextTrackUpdate: ((Track?) -> Void)?
    var onWatchdogChanged: ((Bool) -> Void)?

    // MARK: - Lifecycle

    func start() {
        onWatchdogChanged?(false)
        fileQueue.async { [weak self] in self?.genreByArtistTitle = self?.loadMegaSegGenreLibrary() ?? [:] }

        let observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(Self.nowPlayingNotification),
            object: nil,
            queue: nil   // delivered on whatever thread DNC chooses; we dispatch to fileQueue
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
        fileQueue.async { [weak self] in
            guard let self else { return }
            timer?.cancel()
            timer = nil
            doPoll()
        }
    }

    private func schedulePoll(after delay: TimeInterval) {
        let t = DispatchSource.makeTimerSource(queue: fileQueue)
        t.schedule(deadline: .now() + delay)
        t.setEventHandler { [weak self] in self?.doPoll() }
        t.resume()
        timer?.cancel()   // release any previous source before replacing it
        timer = t
    }

    // MARK: - Polling

    private func doPoll() {
        guard isMegaSegRunning() else {
            handleFailure()
            DispatchQueue.main.async { [weak self] in
                self?.onNextTrackUpdate?(nil)
                self?.onTrackUpdate?(nil, .stopped)
            }
            schedulePoll(after: currentInterval)
            return
        }

        guard let currentTrack = readNowPlaying() else {
            handleFailure()
            DispatchQueue.main.async { [weak self] in
                self?.onNextTrackUpdate?(nil)
                self?.onTrackUpdate?(nil, .stopped)
            }
            schedulePoll(after: currentInterval)
            return
        }

        handleSuccess()
        pollCount += 1

        // Always read ComingUp.html for accurate next-track info; emit full playlist on interval.
        let upcoming = readComingUp()
        let shouldEmitPlaylist = pollCount % playlistRefreshInterval == 0

        DispatchQueue.main.async { [weak self] in
            self?.onNextTrackUpdate?(upcoming.first)
            self?.onTrackUpdate?(currentTrack, .playing)
            if shouldEmitPlaylist {
                self?.onPlaylistUpdate((tracks: [currentTrack] + upcoming, currentIndex: 0))
            }
        }
        schedulePoll(after: currentInterval)
    }

    // MARK: - App detection

    private func isMegaSegRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == Self.bundleID }
    }

    // MARK: - NowPlaying parsing (HTML primary, txt fallback)

    private func readNowPlaying() -> Track? {
        let htmlURL = Self.logsDir.appendingPathComponent("NowPlaying.html")
        if let raw = try? String(contentsOf: htmlURL, encoding: .utf8),
           let track = parseNowPlayingHTML(raw) {
            return track
        }
        // Fallback: NowPlaying.txt — format is "{Artist} - {Title} - {Album}"
        let txtURL = Self.logsDir.appendingPathComponent("NowPlaying.txt")
        guard let raw = try? String(contentsOf: txtURL, encoding: .utf8) else { return nil }
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, line != "n/a" else { return nil }
        return parseNowPlayingTxt(line)
    }

    /// Parses NowPlaying.html which contains labeled spans and JS conditionals, e.g.:
    ///   <font size=+2 color=ffffff> {Title}</font>
    ///   if ('{Artist}' == '') {document.getElementById('artist')...
    ///   if ('{Album}' == '')  {document.getElementById('album')...
    ///   if ('{Year}' == '')   {document.getElementById('year')...
    private func parseNowPlayingHTML(_ html: String) -> Track? {
        guard let title = extractBetween(html, before: "<font size=+2 color=ffffff>", after: "</font>")?
            .trimmingCharacters(in: .whitespaces), !title.isEmpty else { return nil }

        let artist = extractJSString(html, elementId: "artist") ?? ""
        let yearStr = extractJSString(html, elementId: "year").flatMap { Int($0) }
        let year = (yearStr ?? 0) > 0 ? yearStr : nil

        return Track(
            title:        title,
            artist:       artist,
            genre:        genreByArtistTitle[megaSegArtistTitleKey(artist, title)]
                              ?? SetlistManager.genre(forArtist: artist, title: title)
                              ?? "",
            persistentID: "\(artist)\u{2013}\(title)",
            year:         year,
            comment:      nil,
            albumArtist:  nil
        )
    }

    /// Fallback: NowPlaying.txt format is "{Artist} - {Title} - {Album}" with plain hyphens.
    /// Uses the first " - " to separate artist from the rest; ambiguous for artists with hyphens
    /// but better than failing silently.
    private func parseNowPlayingTxt(_ line: String) -> Track? {
        let (artist, rest) = splitOnFirst(line, separator: " - ")
        let (title, _)     = splitOnFirst(rest, separator: " - ")
        guard !title.isEmpty else { return nil }
        return Track(
            title:        title,
            artist:       artist,
            genre:        genreByArtistTitle[megaSegArtistTitleKey(artist, title)]
                              ?? SetlistManager.genre(forArtist: artist, title: title)
                              ?? "",
            persistentID: "\(artist)\u{2013}\(title)",
            year:         nil,
            comment:      nil,
            albumArtist:  nil
        )
    }

    // MARK: - ComingUp.html parsing

    private func readComingUp() -> [Track] {
        let url = Self.logsDir.appendingPathComponent("ComingUp.html")
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseComingUpHTML(raw)
    }

    /// Parses ComingUp.html where tracks appear between <hr> separators as three <br>-terminated lines:
    ///   Line 1: {Title}  (may include a trailing duration like "(50')" — kept as-is)
    ///   Line 2: {Artist}
    ///   Line 3: {Album} ({Year})  — year is 4 digits; other parenthetical suffixes are ignored
    private func parseComingUpHTML(_ html: String) -> [Track] {
        var tracks: [Track] = []

        for block in html.components(separatedBy: "<hr>") {
            // Strip HTML comments and tags, split on <br>
            let lines = block
                .components(separatedBy: "<br>")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .compactMap { line -> String? in
                    // Drop HTML comment lines (e.g. <!--10-->)
                    guard !line.hasPrefix("<!--") else { return nil }
                    // Strip any residual HTML tags
                    let stripped = line.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }

            guard lines.count >= 2 else { continue }

            let title  = lines[0]
            let artist = lines[1]

            var year: Int? = nil
            if lines.count >= 3 {
                let albumLine = lines[2]
                // Extract a 4-digit year from the last parenthetical, e.g. "Album Name (1950)"
                if albumLine.hasSuffix(")"), let parenRange = albumLine.range(of: "(", options: .backwards) {
                    let candidate = albumLine[albumLine.index(after: parenRange.lowerBound)..<albumLine.index(before: albumLine.endIndex)]
                    if let y = Int(candidate), y >= 1900, y <= 2100 {
                        year = y
                    }
                }
            }

            tracks.append(Track(
                title:        title,
                artist:       artist,
                genre:        genreByArtistTitle[megaSegArtistTitleKey(artist, title)]
                              ?? SetlistManager.genre(forArtist: artist, title: title)
                              ?? "",
                persistentID: "\(artist)\u{2013}\(title)",
                year:         year,
                comment:      nil,
                albumArtist:  nil
            ))
        }

        return tracks
    }

    // MARK: - MegaSeg Library Database (genre lookup)

    /// Parses ~/Music/MegaSeg/Library/MegaSeg Database into an artist+title → genre map.
    /// Records are separated by "99* ----"; each field is "NN] value".
    private func loadMegaSegGenreLibrary() -> [String: String] {
        guard let content = try? String(contentsOf: Self.libraryFile, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for record in content.components(separatedBy: "99* ----") {
            var title = ""; var artist = ""; var genre = ""
            for line in record.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("01]") { title  = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
                if t.hasPrefix("02]") { artist = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
                if t.hasPrefix("06]") { genre  = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
            }
            guard !title.isEmpty, !genre.isEmpty else { continue }
            result[megaSegArtistTitleKey(artist, title)] = genre
        }
        return result
    }

    private func megaSegArtistTitleKey(_ artist: String, _ title: String) -> String {
        let n: (String) -> String = { $0.decomposedStringWithCanonicalMapping.lowercased() }
        return "\(n(artist))\u{0}\(n(title))"
    }

    // MARK: - HTML extraction helpers

    /// Returns the substring between the first occurrence of `before` and the next `after`.
    private func extractBetween(_ s: String, before: String, after: String) -> String? {
        guard let startRange = s.range(of: before) else { return nil }
        let tail = s[startRange.upperBound...]
        guard let endRange = tail.range(of: after) else { return nil }
        return String(tail[tail.startIndex..<endRange.lowerBound])
    }

    /// Extracts the string value from a NowPlaying.html JS conditional of the form:
    ///   if ('{value}' == '') {document.getElementById('{elementId}')...
    private func extractJSString(_ html: String, elementId: String) -> String? {
        let marker = "' == '') {document.getElementById('\(elementId)')"
        guard let markerRange = html.range(of: marker) else { return nil }
        let before = String(html[html.startIndex..<markerRange.lowerBound])
        guard let ifRange = before.range(of: "if ('", options: .backwards) else { return nil }
        return String(before[ifRange.upperBound...])
    }

    // MARK: - String helpers

    /// Splits on the last occurrence of `separator`, returning both halves trimmed.
    private func splitOnLast(_ s: String, separator: String) -> (String, String) {
        guard let range = s.range(of: separator, options: .backwards) else {
            return (s.trimmingCharacters(in: .whitespaces), "")
        }
        return (
            s[s.startIndex..<range.lowerBound].trimmingCharacters(in: .whitespaces),
            s[range.upperBound...].trimmingCharacters(in: .whitespaces)
        )
    }

    /// Splits on the first occurrence of `separator`, returning both halves trimmed.
    private func splitOnFirst(_ s: String, separator: String) -> (String, String) {
        guard let range = s.range(of: separator) else {
            return (s.trimmingCharacters(in: .whitespaces), "")
        }
        return (
            s[s.startIndex..<range.lowerBound].trimmingCharacters(in: .whitespaces),
            s[range.upperBound...].trimmingCharacters(in: .whitespaces)
        )
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
}

// MARK: - MusicPlayerSource conformance

extension MegaSegMonitor: MusicPlayerSource {

    var supportsPlaylist: Bool { true }

    func pollNow() {
        fileQueue.async { [weak self] in
            guard let self else { return }
            timer?.cancel()
            timer = nil
            doPoll()
        }
    }

    func triggerPlaylistFetch() {
        fileQueue.async { [weak self] in
            guard let self else { return }
            let upcoming = readComingUp()
            guard let current = readNowPlaying() else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onPlaylistUpdate((tracks: [current] + upcoming, currentIndex: 0))
            }
        }
    }

    func fetchArtwork(for track: Track) async -> NSImage? {
        let url = Self.logsDir.appendingPathComponent("NowPlaying.jpg")
        return NSImage(contentsOf: url)
    }
}
