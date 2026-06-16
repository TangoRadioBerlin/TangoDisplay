import Foundation

public struct Track: Equatable, Hashable, Codable {
    public let title: String
    public let artist: String
    public let genre: String        // empty string when Music.app returns nothing
    public let persistentID: String // stable identity across polls
    public let year: Int?           // nil when Music.app returns 0 or nothing
    public let comment: String?     // nil when player returns nothing or field is empty
    public let albumArtist: String? // nil when unavailable or empty
    public let grouping: String?    // nil when unavailable or empty
    public let replayGainInfo: ReplayGainInfo? // nil when not present or not a built-in player track
    public let bpm: Int?            // beats per minute from file tags; nil when absent/zero

    public init(title: String, artist: String, genre: String,
                persistentID: String, year: Int? = nil, comment: String? = nil,
                albumArtist: String? = nil, grouping: String? = nil,
                replayGainInfo: ReplayGainInfo? = nil, bpm: Int? = nil) {
        self.title = title
        self.artist = artist
        self.genre = genre
        self.persistentID = persistentID
        self.year = year
        self.comment = comment
        self.albumArtist = albumArtist
        self.grouping = grouping
        self.replayGainInfo = replayGainInfo
        self.bpm = bpm
    }
}
