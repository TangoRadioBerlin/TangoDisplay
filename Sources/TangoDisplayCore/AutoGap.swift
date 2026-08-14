import Foundation

/// Result of planning the silence around a track for the auto-gap feature. All values are seconds.
public struct AutoGapPlan: Equatable {
    /// Silence to insert before the track.
    public var insert: Double
    /// Leading silence to skip at the start of the track (force mode only).
    public var skipLeading: Double
    /// Trailing silence to trim from the end of the track (force mode only).
    public var trimTrailing: Double

    public init(insert: Double, skipLeading: Double, trimTrailing: Double) {
        self.insert = insert
        self.skipLeading = skipLeading
        self.trimTrailing = trimTrailing
    }

    /// Seconds of detected silence that are always left untrimmed at each end in
    /// force mode. The silence analyzer classifies anything below its peak
    /// threshold (≈ −36 dBFS) as silence, so quiet fade-outs/intros would
    /// otherwise be cut audibly. Costs at most this much extra gap per side.
    public static let defaultSafetyMargin = 0.5
}

/// Plans the auto-gap around a track being loaded.
///
/// - Pad mode (`force == false`): only top up to `target` — insert `max(0, target − (prevEnd + leading))`,
///   never trim. Existing silence (previous track's tail + this track's head) counts toward the target.
/// - Force mode (`force == true`): make the audible gap exactly `target` — skip this track's leading
///   silence, trim its trailing silence, and insert exactly `target` (the previous track's tail was
///   trimmed when it was loaded, so it doesn't count here). `safetyMargin` seconds of the detected
///   silence are kept at each end so misclassified quiet music is never cut.
/// Effective playback window of a file, in seconds, combining a user-set trim
/// (`trimStart`/`trimEnd`, nil = untrimmed end) with force-mode silence trims
/// (`skipLeading`/`trimTrailing`). Both constraints apply: playback starts at
/// the later of the two starts and ends at the earlier of the two ends, each
/// clamped to `[0, duration]`. A degenerate result (`end <= start`) means the
/// constraints conflict — the caller plays the full file instead.
public func playbackWindow(duration: Double, trimStart: Double?, trimEnd: Double?,
                           skipLeading: Double = 0, trimTrailing: Double = 0)
    -> (start: Double, end: Double) {
    let dur = max(0, duration)
    var start = min(max(0, skipLeading), dur)
    var end = max(0, dur - max(0, trimTrailing))
    if let t = trimStart { start = max(start, min(max(0, t), dur)) }
    if let t = trimEnd { end = min(end, min(max(0, t), dur)) }
    return (start, end)
}

/// Silence analysis bound to a specific (current, next) transition.
///
/// The background analysis for "track A ends, track B starts" finishes long
/// after it was scheduled; by then the user may have reordered, skipped or
/// marked tracks played. Binding the measured values to the exact entry pair
/// means a stale result can never shape the wrong transition — the caller
/// falls back to a conservative full-target plan instead.
public struct PreparedAutoGap: Equatable {
    public let currentID: UUID
    public let nextID: UUID
    /// Trailing silence of the outgoing (current) track.
    public let prevEnd: Double
    /// Leading silence of the incoming (next) track.
    public let leading: Double
    /// Trailing silence of the incoming track (force-trim input when it loads).
    public let trailing: Double

    public init(currentID: UUID, nextID: UUID, prevEnd: Double, leading: Double, trailing: Double) {
        self.currentID = currentID
        self.nextID = nextID
        self.prevEnd = prevEnd
        self.leading = leading
        self.trailing = trailing
    }

    /// The auto-gap plan for loading `nextID` right after `currentID`, or nil
    /// when the prepared pair doesn't match (stale analysis).
    public func plan(currentID: UUID, nextID: UUID, target: Double, force: Bool,
                     safetyMargin: Double = AutoGapPlan.defaultSafetyMargin) -> AutoGapPlan? {
        guard currentID == self.currentID, nextID == self.nextID else { return nil }
        return autoGapPlan(leading: leading, trailing: trailing, prevEnd: prevEnd,
                           target: target, force: force, safetyMargin: safetyMargin)
    }
}

/// Resolves the per-entry tri-state auto-gap override (nil = follow the global
/// first-track rule; true = force skip; false = force apply). Assumes auto-gap
/// is globally enabled.
public func effectiveAutoGapIgnored(override: Bool?, isFirstTrack: Bool, ignoreFirstTrack: Bool) -> Bool {
    override ?? (ignoreFirstTrack && isFirstTrack)
}

/// One-time migration of the legacy boolean `ignoresAutoGap` flag: an explicit
/// skip stays a forced skip; the legacy default (false/absent) becomes
/// "follow the global rule" rather than a forced apply.
public func migratedAutoGapOverride(legacyIgnores: Bool?) -> Bool? {
    legacyIgnores == true ? true : nil
}

public func autoGapPlan(leading: Double, trailing: Double, prevEnd: Double,
                        target: Double, force: Bool,
                        safetyMargin: Double = AutoGapPlan.defaultSafetyMargin) -> AutoGapPlan {
    let t = max(0, target)
    let lead = max(0, leading)
    let trail = max(0, trailing)
    let prev = max(0, prevEnd)
    let margin = max(0, safetyMargin)
    if force {
        return AutoGapPlan(insert: t,
                           skipLeading: max(0, lead - margin),
                           trimTrailing: max(0, trail - margin))
    } else {
        return AutoGapPlan(insert: max(0, t - (prev + lead)), skipLeading: 0, trimTrailing: 0)
    }
}
