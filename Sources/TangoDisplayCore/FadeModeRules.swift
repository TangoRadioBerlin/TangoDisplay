import Foundation

/// Which fade transition the built-in player has in flight (if any).
///
/// Moved here from the App target so the mutual-exclusion invariant below is
/// unit-testable: the two directions must never run concurrently, or the
/// later task overwrites `preFadeVolume` from the already-faded-down volume
/// and the earlier task's completion (volume restore / skipNext) silently
/// never fires (its own `fadeMode == <its mode>` guard then fails).
public enum FadeMode: Equatable {
    case none
    case fadeAndStop
    case fadeAndContinue
}

/// Whether a new fade may start, given the one already in flight.
public enum FadeModeRules {
    /// - No fade running (`.none`): either direction may start.
    /// - The SAME direction requested again: allowed — this is the existing
    ///   toggle-to-cancel gesture (`AppState.transportFadeAndStop`/
    ///   `transportFadeAndContinue` handle that case themselves before
    ///   consulting this rule).
    /// - The OTHER direction while one is active: blocked. This mirrors the
    ///   `.disabled(...)` invariant the transport buttons already enforce in
    ///   the view (`PlayerControlsView.fadeButtons`) — it must also hold at
    ///   the model layer, since RemoteControlBridge.handleTransport calls
    ///   these transitions directly with no UI in between.
    public static func canStart(_ requested: FadeMode, given current: FadeMode) -> Bool {
        current == .none || current == requested
    }
}
