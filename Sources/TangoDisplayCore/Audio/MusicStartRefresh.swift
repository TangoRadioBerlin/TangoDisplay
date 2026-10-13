import Foundation

/// When the Music library table and its path index are worth rebuilding. Both
/// scans are expensive on a large library (seconds), so every trigger — launch,
/// draggingEntered, drop, paste — funnels through these two decisions.
public enum MusicLibraryScanPolicy {
    /// Minimum spacing between two rebuilds of the location index.
    public static let pathIndexRebuildInterval: TimeInterval = 60

    /// A table that was never loaded, or is at least `minAge` old, reloads.
    public static func needsReload(loadedAt: Date?, now: Date, minAge: TimeInterval) -> Bool {
        guard let loadedAt else { return true }
        return now.timeIntervalSince(loadedAt) >= minAge
    }

    /// Whether a path lookup that missed should rebuild the location index.
    ///
    /// The index survives table reloads — a track's location rarely changes, so a
    /// hit against an older index is still right. Only a miss can mean "added to
    /// Music since the index was built", and only when the table has reloaded
    /// since (`staleSinceReload`). A path that already missed a complete index
    /// (`knownMiss` — a Finder file, not a library track) never pays for another.
    public static func shouldRebuildPathIndex(hasIndex: Bool, staleSinceReload: Bool, knownMiss: Bool,
                                              lastBuilt: Date?, now: Date,
                                              minInterval: TimeInterval = pathIndexRebuildInterval) -> Bool {
        guard hasIndex else { return true }
        guard staleSinceReload, !knownMiss else { return false }
        guard let lastBuilt else { return true }
        return now.timeIntervalSince(lastBuilt) >= minInterval
    }
}

/// What a setlist entry currently caches about its Music library track.
public struct MusicStartSnapshot {
    public let id: UUID
    public let persistentID: String?
    public let start: Double?
    public let end: Double?

    public init(id: UUID, persistentID: String?, start: Double?, end: Double?) {
        self.id = id; self.persistentID = persistentID; self.start = start; self.end = end
    }
}

/// What the library says about that track right now.
public struct MusicStartLookup {
    public let persistentID: String
    public let start: Double?
    public let end: Double?

    public init(persistentID: String, start: Double?, end: Double?) {
        self.persistentID = persistentID; self.start = start; self.end = end
    }
}

public struct MusicStartUpdate: Equatable {
    public let id: UUID
    public let persistentID: String
    public let start: Double?
    public let end: Double?

    public init(id: UUID, persistentID: String, start: Double?, end: Double?) {
        self.id = id; self.persistentID = persistentID; self.start = start; self.end = end
    }
}

/// The entries whose cached Music values differ from the library, in setlist
/// order. An entry with no lookup is not a library track and is left alone.
///
/// The start time always follows Music, including its removal. The stop time
/// lives in the entry's trim end, which the user may also have set by hand, so
/// it is imported only on request (`includeStop`) and only when Music actually
/// has one — a missing stop time never clears a trim end.
public func musicStartUpdates(entries: [MusicStartSnapshot], lookups: [UUID: MusicStartLookup],
                              includeStop: Bool = false) -> [MusicStartUpdate] {
    entries.compactMap { e in
        guard let l = lookups[e.id] else { return nil }
        let end = includeStop ? (l.end ?? e.end) : e.end
        guard l.persistentID != e.persistentID || l.start != e.start || end != e.end else { return nil }
        return MusicStartUpdate(id: e.id, persistentID: l.persistentID, start: l.start, end: end)
    }
}
