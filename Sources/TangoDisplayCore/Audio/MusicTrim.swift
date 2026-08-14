import Foundation

/// Converts Music's per-track start/stop (Song Info → Options), given in milliseconds,
/// into playback-trim seconds. Music reports `startMs == 0` and `stopMs == 0`-or-`totalMs`
/// when the checkboxes are off, so those map to `nil` (no trim on that end).
public func musicTrimSeconds(startMs: Int, stopMs: Int, totalMs: Int) -> (start: Double?, end: Double?) {
    let start = startMs > 0 ? Double(startMs) / 1000 : nil
    let end   = (stopMs > 0 && stopMs < totalMs) ? Double(stopMs) / 1000 : nil
    return (start, end)
}
