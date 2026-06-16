import Foundation

/// Backward-compatible v2 of the LAN remote-control protocol (see docs/remote-control-v2.md).
///
/// These are pure, AppKit-free models + helpers so the wire format is unit-testable without the
/// bridge. v1 clients (the phone "Setlist Remote") ignore the new `type`s and optional fields, so
/// adding them never breaks the existing read + volume/ReplayGain surface.
public enum RemoteProtocol {
    /// Advertised in `hello.protocolVersion`.
    public static let version = 2
}

/// Capabilities the server advertises in `hello.capabilities[]`. Controller capabilities are only
/// advertised when the DJ has enabled remote setlist control.
public enum RemoteCapability: String, Codable, CaseIterable {
    case transport
    case setlistRead = "setlist.read"
}

/// Reason strings returned in `ack.rejected.reason`.
public enum RemoteRejectReason {
    public static let controllerDisabled = "controllerDisabled"
    public static let builtInPlayerNotActive = "builtInPlayerNotActive"
    public static let unknownEntry = "unknownEntry"
    public static let malformed = "malformed"
}

// MARK: - Inbound commands

/// `{ "type": "transport", "id"?: String, "action": <Action>, "fadeSec"?: Double }`
public struct RemoteTransportCommand: Codable, Equatable {
    public enum Action: String, Codable, CaseIterable {
        case play, pause, resume, next, previous, stop, fadeAndStop, fadeAndContinue
    }
    public var id: String?
    public var action: Action
    public var fadeSec: Double?

    public init(id: String? = nil, action: Action, fadeSec: Double? = nil) {
        self.id = id
        self.action = action
        self.fadeSec = fadeSec
    }
}

/// `{ "type": "playEntry", "id"?: String, "entryId": String }`
public struct RemotePlayEntryCommand: Codable, Equatable {
    public var id: String?
    public var entryId: String

    public init(id: String? = nil, entryId: String) {
        self.id = id
        self.entryId = entryId
    }
}

/// Decodes inbound controller commands from raw frame data. An unknown action / malformed body
/// fails to decode and returns nil → the caller replies `ack.rejected.reason = malformed`.
public enum RemoteCommandDecoder {
    public static func transport(from data: Data) -> RemoteTransportCommand? {
        try? JSONDecoder().decode(RemoteTransportCommand.self, from: data)
    }
    public static func playEntry(from data: Data) -> RemotePlayEntryCommand? {
        try? JSONDecoder().decode(RemotePlayEntryCommand.self, from: data)
    }
}

// MARK: - Outbound messages

/// `{ "type": "ack", "id"?: String, "ok": Bool, "rejected"?: { "reason": String } }`
public struct RemoteAck: Codable, Equatable {
    public struct Rejection: Codable, Equatable {
        public var reason: String
        public init(reason: String) { self.reason = reason }
    }
    public var type: String
    public var id: String?
    public var ok: Bool
    public var rejected: Rejection?

    public init(id: String?, ok: Bool, rejectedReason: String? = nil) {
        self.type = "ack"
        self.id = id
        self.ok = ok
        self.rejected = rejectedReason.map(Rejection.init(reason:))
    }
}

/// One entry in the additive `state.setlist[]` broadcast. Deliberately carries NO file path.
/// `clientRef` is the opaque controller-supplied id echoed verbatim (nil until loadSetlist exists).
public struct RemoteSetlistEntryDTO: Codable, Equatable {
    public var entryId: String
    public var clientRef: String?
    public var title: String
    public var artist: String
    public var genre: String
    public var isCortina: Bool
    public var state: String          // queued | playing | paused | played
    public var durationSec: Double?
    public var isPerformance: Bool

    public init(entryId: String, clientRef: String? = nil, title: String, artist: String,
                genre: String, isCortina: Bool, state: String,
                durationSec: Double? = nil, isPerformance: Bool = false) {
        self.entryId = entryId
        self.clientRef = clientRef
        self.title = title
        self.artist = artist
        self.genre = genre
        self.isCortina = isCortina
        self.state = state
        self.durationSec = durationSec
        self.isPerformance = isPerformance
    }
}

/// Encodes an outbound message to a JSON string for the WebSocket text frame.
public enum RemoteJSON {
    public static func encodeToString<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
