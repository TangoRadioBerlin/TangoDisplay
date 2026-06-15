import Foundation

/// When the TDJ (DJ) name is shown on the dancer display.
/// Ported from upstream v3.25.2; the visibility rule lives in Core so it is testable.
public enum TdjNameVisibility: String, CaseIterable, Identifiable {
    case playing
    case idlePaused
    case always

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .playing:    return "Any track playing"
        case .idlePaused: return "Idle / Paused"
        case .always:     return "Always"
        }
    }

    /// Whether the name should be visible in the given display mode.
    /// `.playing` covers cortinas too — the DJ is still working the floor.
    /// Performance mode is intentionally excluded: `PerformanceView` is a dedicated,
    /// overlay-free full-screen layout, so the TDJ name is never drawn there. Keeping
    /// the rule honest (rather than returning true and silently not rendering) avoids
    /// a misleading "visible" setting.
    public func isVisible(in mode: DisplayMode) -> Bool {
        switch self {
        case .playing:    return mode == .playing || mode == .cortina
        case .idlePaused: return mode == .idle || mode == .paused
        case .always:     return mode != .performance
        }
    }
}
