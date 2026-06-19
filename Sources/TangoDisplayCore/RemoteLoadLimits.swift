import Foundation

/// Entry-count cap for remote setlist-write commands (loadSetlist, replaceFuture).
/// Each entry triggers an AVFoundation metadata read on the MainActor; an unbounded
/// array lets an authenticated controller freeze the UI and amplify disk / broadcast
/// work with a single ~1-MiB WebSocket frame.
///
/// A full milonga evening is typically ≤ 100 tracks; 500 is a generous ceiling that
/// covers any realistic DJ use-case while bounding worst-case cost per command.
public enum RemoteLoadLimits {
    /// Maximum number of entries per loadSetlist / replaceFuture command.
    public static let maxSetlistEntries = 500

    /// Returns true when `count` is at or below the cap.
    public static func isWithinLimit(_ count: Int) -> Bool {
        count <= maxSetlistEntries
    }
}
