import Foundation
import AppKit
import TangoDisplayCore

struct JRiverZone: Identifiable, Equatable {
    let id: Int
    let name: String
}

final class JRiverPoller: MusicPlayerSource {

    private let baseURL = "http://127.0.0.1:52199/MCWS/v1"
    private let zoneID: Int
    private let session = URLSession.shared
    private let timerQueue = DispatchQueue(label: "com.tangodisplay.jriverpollertimer", qos: .utility)

    init(zoneID: Int = -1) {
        self.zoneID = zoneID
    }

    private var timer: DispatchSourceTimer?
    private var consecutiveFailures = 0
    private var currentInterval: TimeInterval = 2.0
    private let normalInterval: TimeInterval = 2.0
    private let maxInterval: TimeInterval = 30.0
    private let failuresBeforeWatchdog = 3

    private var pollCount = 0
    private let playlistRefreshInterval = 10
    private var currentPlayingIndex: Int = 0
    private var totalPlayingNowTracks: Int = 0
    private var hasInitialPlaylist = false

    // MARK: - Protocol

    var onTrackUpdate: ((Track?, PlayerState) -> Void)?
    var onPlaylistUpdate: ((tracks: [Track], currentIndex: Int)?) -> Void = { _ in }
    var onNextTrackUpdate: ((Track?) -> Void)?
    var onWatchdogChanged: ((Bool) -> Void)?
    var supportsPlaylist: Bool { true }

    // MARK: - Lifecycle

    func start() {
        schedulePoll(after: normalInterval)
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func pollNow() {
        timer?.cancel()
        timer = nil
        doPoll()
    }

    func triggerPlaylistFetch() {
        fetchPlaylistRange()
        if let url = URL(string: "\(baseURL)/Playback/Info?Zone=\(zoneID)&Format=XML") {
            session.dataTask(with: url) { [weak self] data, _, _ in
                guard let self,
                      let data,
                      let xml = String(data: data, encoding: .utf8) else {
                    DispatchQueue.main.async { self?.onNextTrackUpdate?(nil) }
                    return
                }
                let nextFileKey = self.extractItemValue(xml, itemName: "NextFileKey")
                if !nextFileKey.isEmpty {
                    self.fetchNextTrackMetadata(fileKey: nextFileKey)
                } else {
                    DispatchQueue.main.async { self.onNextTrackUpdate?(nil) }
                }
            }.resume()
        }
    }

    // MARK: - Artwork

    func fetchArtwork(for track: Track) async -> NSImage? {
        let fileKey = track.persistentID
        guard !fileKey.isEmpty,
              let url = URL(string: "\(baseURL)/File/GetImage?File=\(fileKey)&Type=Thumb&Width=0&Height=0") else {
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Scheduling

    private func schedulePoll(after interval: TimeInterval) {
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + interval)
        t.setEventHandler { [weak self] in self?.doPoll() }
        t.resume()
        timer?.cancel()   // release any previous source before replacing it
        timer = t
    }

    // MARK: - Step 1: Playback state + current track basics

    private func doPoll() {
        guard let url = URL(string: "\(baseURL)/Playback/Info?Zone=\(zoneID)&Fields=Genre&Format=XML") else {
            handleFailure()
            DispatchQueue.main.async {
                self.onTrackUpdate?(nil, .stopped)
                self.onNextTrackUpdate?(nil)
            }
            schedulePoll(after: currentInterval)
            return
        }

        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }

            guard error == nil, let data, let xml = String(data: data, encoding: .utf8) else {
                self.handleFailure()
                DispatchQueue.main.async {
                    self.onTrackUpdate?(nil, .stopped)
                    self.onNextTrackUpdate?(nil)
                }
                self.schedulePoll(after: self.currentInterval)
                return
            }

            let stateValue   = self.extractItemValue(xml, itemName: "State")
            let fileKey      = self.extractItemValue(xml, itemName: "FileKey")
            let title        = self.decodeXML(self.extractItemValue(xml, itemName: "Name"))
            let artist       = self.decodeXML(self.extractItemValue(xml, itemName: "Artist"))
            let genre        = self.decodeXML(self.extractItemValue(xml, itemName: "Genre"))
            let nextFileKey  = self.extractItemValue(xml, itemName: "NextFileKey")

            if let idx = Int(self.extractItemValue(xml, itemName: "PlayingNowPosition")) {
                self.currentPlayingIndex = idx
            }
            if let total = Int(self.extractItemValue(xml, itemName: "PlayingNowTracks")) {
                self.totalPlayingNowTracks = total
            }

            let playerState: PlayerState
            switch stateValue {
            case "2": playerState = .playing
            case "1": playerState = .paused
            default:  playerState = .stopped
            }

            guard playerState == .playing && !fileKey.isEmpty else {
                self.handleSuccess()
                DispatchQueue.main.async {
                    self.onTrackUpdate?(nil, playerState)
                    self.onNextTrackUpdate?(nil)
                }
                self.schedulePoll(after: self.currentInterval)
                return
            }

            self.pollCount += 1

            // Fire onNextTrackUpdate using NextFileKey from this same response
            if !nextFileKey.isEmpty {
                self.fetchNextTrackMetadata(fileKey: nextFileKey)
            } else {
                DispatchQueue.main.async { self.onNextTrackUpdate?(nil) }
            }

            // Step 2: enrich current track with albumArtist, year, comment
            self.fetchMetadata(fileKey: fileKey, title: title, artist: artist, genre: genre, state: playerState)

            if !self.hasInitialPlaylist {
                self.fetchPlaylistRange()
                self.hasInitialPlaylist = true
            } else if self.pollCount % self.playlistRefreshInterval == 0 {
                self.fetchPlaylistRange()
            }
        }.resume()
    }

    // MARK: - Step 2: Enrich current track metadata

    private func fetchMetadata(fileKey: String, title: String, artist: String, genre: String, state: PlayerState) {
        guard let url = URL(string: "\(baseURL)/File/GetInfo?File=\(fileKey)&Fields=Album%20Artist,Date%20(year),Comment,Grouping&Format=XML") else {
            let track = Track(title: title, artist: artist, genre: genre, persistentID: fileKey, year: nil, comment: nil, albumArtist: nil)
            handleSuccess()
            DispatchQueue.main.async { self.onTrackUpdate?(track, state) }
            schedulePoll(after: currentInterval)
            return
        }

        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }

            var albumArtist: String? = nil
            var year: Int? = nil
            var comment: String? = nil
            var grouping: String? = nil

            if let data, let xml = String(data: data, encoding: .utf8) {
                let aa = self.decodeXML(self.extractFieldValue(xml, fieldName: "Album Artist"))
                if !aa.isEmpty { albumArtist = aa }

                let yr = self.extractFieldValue(xml, fieldName: "Date (year)")
                if !yr.isEmpty { year = Int(yr) }

                let cm = self.decodeXML(self.extractFieldValue(xml, fieldName: "Comment"))
                if !cm.isEmpty { comment = cm }

                let gp = self.decodeXML(self.extractFieldValue(xml, fieldName: "Grouping"))
                if !gp.isEmpty { grouping = gp }
            }

            let track = Track(
                title: title,
                artist: artist,
                genre: genre,
                persistentID: fileKey,
                year: year,
                comment: comment,
                albumArtist: albumArtist,
                grouping: grouping
            )
            self.handleSuccess()
            DispatchQueue.main.async { self.onTrackUpdate?(track, state) }
            self.schedulePoll(after: self.currentInterval)
        }.resume()
    }

    // MARK: - Next track (cortina preview)

    private func fetchNextTrackMetadata(fileKey: String) {
        guard let url = URL(string: "\(baseURL)/File/GetInfo?File=\(fileKey)&Fields=Name,Artist,Genre,Album%20Artist,Date%20(year),Comment,Grouping&Format=XML") else {
            DispatchQueue.main.async { self.onNextTrackUpdate?(nil) }
            return
        }

        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            guard let data, let xml = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.onNextTrackUpdate?(nil) }
                return
            }

            let title   = self.decodeXML(self.extractFieldValue(xml, fieldName: "Name"))
            let artist  = self.decodeXML(self.extractFieldValue(xml, fieldName: "Artist"))
            let aa      = self.decodeXML(self.extractFieldValue(xml, fieldName: "Album Artist"))
            let genre   = self.decodeXML(self.extractFieldValue(xml, fieldName: "Genre"))
            let yearStr = self.extractFieldValue(xml, fieldName: "Date (year)")
            let cm      = self.decodeXML(self.extractFieldValue(xml, fieldName: "Comment"))
            let gp      = self.decodeXML(self.extractFieldValue(xml, fieldName: "Grouping"))

            let nextTrack = Track(
                title: title,
                artist: artist,
                genre: genre,
                persistentID: fileKey,
                year: Int(yearStr),
                comment: cm.isEmpty ? nil : cm,
                albumArtist: aa.isEmpty ? nil : aa,
                grouping: gp.isEmpty ? nil : gp
            )
            DispatchQueue.main.async { self.onNextTrackUpdate?(nextTrack) }
        }.resume()
    }

    // MARK: - Playlist (lookback + lookahead)

    private func fetchPlaylistRange(lookback: Int = 5, lookahead: Int = 10) {
        guard totalPlayingNowTracks > 0 else { return }

        let startIndex = max(0, currentPlayingIndex - lookback)
        let maxLimit   = totalPlayingNowTracks - startIndex
        let limit      = min(lookback + 1 + lookahead, maxLimit)
        guard limit > 0 else { return }

        guard let url = URL(string: "\(baseURL)/Playback/Playlist?Action=MPL&Zone=\(zoneID)&StartIndex=\(startIndex)&Limit=\(limit)&Format=XML") else {
            return
        }

        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let xml = String(data: data, encoding: .utf8) else { return }

            let tracks = self.parsePlaylistTracks(from: xml)
            guard !tracks.isEmpty else { return }

            let adjustedIndex = min(lookback, self.currentPlayingIndex)
            let safeIndex = min(adjustedIndex, tracks.count - 1)
            DispatchQueue.main.async {
                self.onPlaylistUpdate((tracks: tracks, currentIndex: safeIndex))
            }
        }.resume()
    }

    private func parsePlaylistTracks(from xml: String) -> [Track] {
        var tracks: [Track] = []
        guard let regex = try? NSRegularExpression(pattern: "<Item>(.*?)</Item>", options: .dotMatchesLineSeparators) else {
            return tracks
        }
        let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
        for match in matches {
            guard let range = Range(match.range(at: 1), in: xml) else { continue }
            let item = String(xml[range])

            let title   = decodeXML(extractFieldFromPlaylist(item, fieldName: "Name"))
            let artist  = decodeXML(extractFieldFromPlaylist(item, fieldName: "Artist"))
            let genre   = decodeXML(extractFieldFromPlaylist(item, fieldName: "Genre"))
            let fileKey = extractFieldFromPlaylist(item, fieldName: "Key")
            let aa      = decodeXML(extractFieldFromPlaylist(item, fieldName: "Album Artist"))
            let yearStr = extractFieldFromPlaylist(item, fieldName: "Date (year)")
            let gp      = decodeXML(extractFieldFromPlaylist(item, fieldName: "Grouping"))

            guard !title.isEmpty, !fileKey.isEmpty else { continue }

            tracks.append(Track(
                title: title,
                artist: artist,
                genre: genre,
                persistentID: fileKey,
                year: Int(yearStr),
                comment: nil,
                albumArtist: aa.isEmpty ? nil : aa,
                grouping: gp.isEmpty ? nil : gp
            ))
        }
        return tracks
    }

    // MARK: - Zone discovery

    static func fetchZones(completion: @escaping ([JRiverZone]) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:52199/MCWS/v1/Playback/Zones?Format=XML") else {
            completion([]); return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let xml = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion([]) }; return
            }
            // Response uses flat items: ZoneID0/ZoneName0, ZoneID1/ZoneName1, …
            let countStr = staticExtractItemValue(xml, itemName: "NumberZones")
            guard let count = Int(countStr), count > 0 else {
                DispatchQueue.main.async { completion([]) }; return
            }
            var zones: [JRiverZone] = []
            for i in 0..<count {
                let idStr = staticExtractItemValue(xml, itemName: "ZoneID\(i)")
                let name  = staticExtractItemValue(xml, itemName: "ZoneName\(i)")
                if let id = Int(idStr), !name.isEmpty {
                    zones.append(JRiverZone(id: id, name: name))
                }
            }
            DispatchQueue.main.async { completion(zones) }
        }.resume()
    }

    private static func staticExtractItemValue(_ xml: String, itemName: String) -> String {
        let pattern = "<Item Name=\"\(itemName)\">(.*?)</Item>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else { return "" }
        return String(xml[range])
    }

    // MARK: - XML parsing

    // Playback/Info: <Item Name="...">value</Item>
    private func extractItemValue(_ xml: String, itemName: String) -> String {
        let pattern = "<Item Name=\"\(itemName)\">(.*?)</Item>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else { return "" }
        return String(xml[range])
    }

    // File/GetInfo: <Field Name="...">value</Field>
    private func extractFieldValue(_ xml: String, fieldName: String) -> String {
        let search = "<Field Name=\"\(fieldName)\">"
        guard let start = xml.range(of: search) else { return "" }
        let after = xml[start.upperBound...]
        guard let end = after.range(of: "</Field>") else { return "" }
        return String(after[..<end.lowerBound])
    }

    // Playlist items: <Field Name="...">value</Field>
    private func extractFieldFromPlaylist(_ xml: String, fieldName: String) -> String {
        let pattern = "<Field Name=\"\(fieldName)\">(.*?)</Field>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else { return "" }
        return String(xml[range])
    }

    private func decodeXML(_ s: String) -> String {
        // &amp; must be decoded LAST: doing it first turns "&amp;lt;" into "&lt;",
        // which the next pass would wrongly decode again.
        s.replacingOccurrences(of: "&lt;",   with: "<")
         .replacingOccurrences(of: "&gt;",   with: ">")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&apos;", with: "'")
         .replacingOccurrences(of: "&amp;",  with: "&")
    }

    // MARK: - Watchdog

    private func handleSuccess() {
        let wasWatchdog = consecutiveFailures >= failuresBeforeWatchdog
        consecutiveFailures = 0
        currentInterval = normalInterval
        if wasWatchdog {
            DispatchQueue.main.async { self.onWatchdogChanged?(false) }
        }
    }

    private func handleFailure() {
        consecutiveFailures += 1
        if consecutiveFailures == failuresBeforeWatchdog {
            DispatchQueue.main.async { self.onWatchdogChanged?(true) }
        }
        if consecutiveFailures >= failuresBeforeWatchdog {
            currentInterval = min(currentInterval * 2, maxInterval)
        }
    }
}
