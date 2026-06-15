import Foundation

/// Minimal per-entry info needed to decide whether the dance track following a
/// cortina is a performance track. Mirrors the relevant `SetlistEntry` fields so
/// the lookahead logic is unit-testable in Core (AppKit/SwiftUI-free).
public struct PerformanceLookaheadEntry {
    public let genre: String
    public let isPerformance: Bool
    public let isPlayed: Bool

    public init(genre: String, isPerformance: Bool, isPlayed: Bool) {
        self.genre = genre
        self.isPerformance = isPerformance
        self.isPlayed = isPlayed
    }
}

/// Whether the first still-unplayed, non-cortina entry after `currentIndex` is a
/// performance track. Played entries are skipped; a following cortina ends the
/// search (the next tanda hasn't been reached). Returns false for an out-of-range
/// index or when no dance track follows.
///
/// Shared by `handleCortina` (initial value) and `handlePlaylistUpdate`
/// (recompute on playlist change) so `DisplayState.nextTrackIsPerformance` can
/// never go stale relative to the actual next track.
public func nextDanceTrackIsPerformance(after currentIndex: Int,
                                        entries: [PerformanceLookaheadEntry],
                                        detector: CortinaDetector) -> Bool {
    guard currentIndex >= 0, currentIndex < entries.count else { return false }
    var i = currentIndex + 1
    while i < entries.count {
        let e = entries[i]
        if e.isPlayed { i += 1; continue }
        if detector.isCortina(genre: e.genre) { return false }
        return e.isPerformance
    }
    return false
}
