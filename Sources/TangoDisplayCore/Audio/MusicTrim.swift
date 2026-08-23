import Foundation

/// Converts Music's per-track start/stop (Song Info → Options), given in milliseconds,
/// into playback-trim seconds. Music reports `startMs == 0` and `stopMs == 0`-or-`totalMs`
/// when the checkboxes are off, so those map to `nil` (no trim on that end).
public func musicTrimSeconds(startMs: Int, stopMs: Int, totalMs: Int) -> (start: Double?, end: Double?) {
    let start = startMs > 0 ? Double(startMs) / 1000 : nil
    let end   = (stopMs > 0 && stopMs < totalMs) ? Double(stopMs) / 1000 : nil
    return (start, end)
}

/// Which trim start applies when a track loads. A manual entry trim always
/// wins; otherwise the Music start time applies to every track — cortinas
/// unconditionally, dance tracks unless the entry opted out. nil = start at
/// the file beginning.
public func effectiveTrimStart(entryTrimStart: Double?, musicStart: Double?,
                               isCortina: Bool, ignoresMusicStart: Bool) -> Double? {
    if let entryTrimStart { return entryTrimStart }
    if !isCortina && ignoresMusicStart { return nil }
    return musicStart
}

/// Row marker for the Music start time. `.none` when nothing Music-related is
/// visible: no Music start, or a manual trim that overrides it (the trim badge
/// shows instead).
public enum MusicStartBadge: Equatable {
    case none
    case active(seconds: Double)
    case ignored(seconds: Double)
}

public func musicStartBadge(entryTrimStart: Double?, musicStart: Double?,
                            isCortina: Bool, ignoresMusicStart: Bool) -> MusicStartBadge {
    guard entryTrimStart == nil, let musicStart else { return .none }
    if !isCortina && ignoresMusicStart { return .ignored(seconds: musicStart) }
    return .active(seconds: musicStart)
}
