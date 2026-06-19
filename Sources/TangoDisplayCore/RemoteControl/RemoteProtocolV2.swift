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
    case setlistWrite = "setlist.write"   // Slice 2: loadSetlist + ordering edits
}

/// Reason strings returned in `ack.rejected.reason`.
public enum RemoteRejectReason {
    public static let controllerDisabled = "controllerDisabled"
    public static let builtInPlayerNotActive = "builtInPlayerNotActive"
    public static let unknownEntry = "unknownEntry"
    public static let malformed = "malformed"
    // Slice 2 (loadSetlist / ordering edits)
    public static let entryImmutable = "entryImmutable"
    public static let immutablePosition = "immutablePosition"
    public static let fileNotFound = "fileNotFound"
    public static let unreadable = "unreadable"
    public static let unsupportedType = "unsupportedType"
    public static let pathNotAllowed = "pathNotAllowed"
    public static let tooManyEntries = "tooManyEntries"
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
    public static func loadSetlist(from data: Data) -> RemoteLoadSetlistCommand? {
        try? JSONDecoder().decode(RemoteLoadSetlistCommand.self, from: data)
    }
    public static func insert(from data: Data) -> RemoteSetlistInsertCommand? {
        try? JSONDecoder().decode(RemoteSetlistInsertCommand.self, from: data)
    }
    public static func remove(from data: Data) -> RemoteSetlistRemoveCommand? {
        try? JSONDecoder().decode(RemoteSetlistRemoveCommand.self, from: data)
    }
    public static func move(from data: Data) -> RemoteSetlistMoveCommand? {
        try? JSONDecoder().decode(RemoteSetlistMoveCommand.self, from: data)
    }
    public static func replaceFuture(from data: Data) -> RemoteSetlistReplaceFutureCommand? {
        try? JSONDecoder().decode(RemoteSetlistReplaceFutureCommand.self, from: data)
    }
}

// MARK: - Outbound messages

/// `{ "type": "ack", "id"?: String, "ok": Bool, "rejected"?: {reason},
///    "resolved"?: [{clientRef, entryId}], "failed"?: [{clientRef, reason}] }`
public struct RemoteAck: Codable, Equatable {
    public struct Rejection: Codable, Equatable {
        public var reason: String
        public init(reason: String) { self.reason = reason }
    }
    /// A load entry that loaded successfully, paired with its server-assigned entryId.
    public struct Resolved: Codable, Equatable {
        public var clientRef: String
        public var entryId: String
        public init(clientRef: String, entryId: String) { self.clientRef = clientRef; self.entryId = entryId }
    }
    /// A load entry that failed validation, with the reason.
    public struct Failed: Codable, Equatable {
        public var clientRef: String
        public var reason: String
        public init(clientRef: String, reason: String) { self.clientRef = clientRef; self.reason = reason }
    }
    public var type: String
    public var id: String?
    public var ok: Bool
    public var rejected: Rejection?
    public var resolved: [Resolved]?
    public var failed: [Failed]?

    public init(id: String?, ok: Bool, rejectedReason: String? = nil,
                resolved: [Resolved]? = nil, failed: [Failed]? = nil) {
        self.type = "ack"
        self.id = id
        self.ok = ok
        self.rejected = rejectedReason.map(Rejection.init(reason:))
        self.resolved = resolved
        self.failed = failed
    }

    private enum CodingKeys: String, CodingKey { case type, id, ok, rejected, resolved, failed }

    // Custom encode so absent optionals are omitted (keeps Slice 1 acks as {type,id,ok}).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(ok, forKey: .ok)
        try c.encodeIfPresent(rejected, forKey: .rejected)
        try c.encodeIfPresent(resolved, forKey: .resolved)
        try c.encodeIfPresent(failed, forKey: .failed)
    }
}

/// One entry in the additive `state.setlist[]` broadcast. Deliberately carries NO file path.
/// `clientRef` is the opaque controller-supplied id echoed verbatim (nil until loadSetlist exists).
public struct RemoteSetlistEntryDTO: Codable, Equatable {
    public var entryId: String
    public var clientRef: String?
    public var tandaRef: String?
    public var title: String
    public var artist: String
    public var genre: String
    public var isCortina: Bool
    public var state: String          // queued | playing | paused | played
    public var durationSec: Double?
    public var isPerformance: Bool

    public init(entryId: String, clientRef: String? = nil, tandaRef: String? = nil,
                title: String, artist: String, genre: String, isCortina: Bool, state: String,
                durationSec: Double? = nil, isPerformance: Bool = false) {
        self.entryId = entryId
        self.clientRef = clientRef
        self.tandaRef = tandaRef
        self.title = title
        self.artist = artist
        self.genre = genre
        self.isCortina = isCortina
        self.state = state
        self.durationSec = durationSec
        self.isPerformance = isPerformance
    }
}

// MARK: - Slice 2: load entries, loadSetlist, ordering edits

/// A controller-supplied entry to load — the only place a file path enters the protocol. The path
/// is validated server-side (absolute, existing, readable, supported audio type).
public struct RemoteLoadEntry: Codable, Equatable {
    public var clientRef: String
    public var path: String
    public var title: String?
    public var artist: String?
    public var isCortina: Bool?      // optional, default false
    public var tandaRef: String?

    public var cortina: Bool { isCortina ?? false }
}

public struct RemoteLoadSetlistCommand: Codable, Equatable {
    public enum Mode: String, Codable { case replace, append }
    public var id: String?
    public var mode: Mode
    public var entries: [RemoteLoadEntry]
}

public struct RemoteSetlistInsertCommand: Codable, Equatable {
    public var id: String?
    public var at: Int
    public var entry: RemoteLoadEntry
}

public struct RemoteSetlistRemoveCommand: Codable, Equatable {
    public var id: String?
    public var entryId: String
}

public struct RemoteSetlistMoveCommand: Codable, Equatable {
    public var id: String?
    public var entryId: String
    public var toIndex: Int
}

public struct RemoteSetlistReplaceFutureCommand: Codable, Equatable {
    public var id: String?
    public var entries: [RemoteLoadEntry]
}

/// Pure helpers for the queued-region editing rules (playing/played entries are immutable).
public enum RemoteSetlistEditing {
    /// The first index that may be edited — just past the last playing/played ("locked") entry.
    /// `locked[i]` is true when entry i is playing or already played.
    public static func firstQueuedIndex(locked: [Bool]) -> Int {
        var idx = 0
        for (i, isLocked) in locked.enumerated() where isLocked { idx = i + 1 }
        return idx
    }
}

/// Encodes an outbound message to a JSON string for the WebSocket text frame.
public enum RemoteJSON {
    public static func encodeToString<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
