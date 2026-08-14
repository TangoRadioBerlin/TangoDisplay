import Foundation
import TangoDisplayCore

/// Builds `SetTimingsCalculator.Item`s from a setlist + playback state. Shared by the Set
/// Timings window and the setlist status bar so "Remaining" / "Ends at" / Option-hover
/// "To here" all use the same auto-gap + cortina-as-1-min arithmetic.
enum SetTimingsItems {

    /// - Parameters:
    ///   - through: when set, stops after that entry (Option-hover "end time through this track").
    ///     When nil, the whole remaining set is built and `stopAfterID` (if any) ends it.
    static func build(entries: [SetlistEntry],
                      currentEntryID: UUID?,
                      elapsed: TimeInterval,
                      detector: CortinaDetector,
                      autoGapEnabled: Bool,
                      autoGapIgnoreFirstTrack: Bool,
                      setNotStarted: Bool,
                      stopAfterID: UUID?,
                      through: UUID? = nil) -> [SetTimingsCalculator.Item] {
        var items: [SetTimingsCalculator.Item] = []
        var firstContributingSeen = false
        for entry in entries {
            let isCortina = detector.isCortina(genre: entry.track.genre)
            var contributes = false
            var elapsedForItem: TimeInterval? = nil
            switch entry.state {
            case .playing:
                contributes = true; elapsedForItem = elapsed
            case .paused, .queued:
                contributes = true
            case .played:
                if entry.id == currentEntryID { contributes = true; elapsedForItem = elapsed }
            }
            var addLeadingGap = false
            if contributes {
                let isActive = (elapsedForItem != nil)   // playing / current entry → no preceding gap
                if !isActive {
                    let isFirst = !firstContributingSeen && setNotStarted
                    addLeadingGap = autoGapEnabled &&
                        !entry.autoGapIgnored(isFirstTrack: isFirst,
                                              ignoreFirstTrack: autoGapIgnoreFirstTrack)
                }
                firstContributingSeen = true
            }
            // Trimmed tracks contribute their playback-window length; the current
            // entry's absolute elapsed is normalised to window-relative time.
            let span = timingSpan(duration: entry.duration ?? 0,
                                  trimStart: entry.trimStartSeconds,
                                  trimEnd: entry.trimEndSeconds,
                                  absoluteElapsed: elapsedForItem)
            items.append(.init(duration: span.duration, isCortina: isCortina, elapsed: span.elapsed,
                               contributes: contributes, addLeadingGap: addLeadingGap))
            if let t = through {
                if entry.id == t { break }
            } else if let stopID = stopAfterID, entry.id == stopID {
                break
            }
        }
        return items
    }
}
