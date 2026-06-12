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
    /// `.playing` covers cortinas and performances too — the DJ is still working the floor.
    public func isVisible(in mode: DisplayMode) -> Bool {
        switch self {
        case .playing:    return mode == .playing || mode == .cortina || mode == .performance
        case .idlePaused: return mode == .idle || mode == .paused
        case .always:     return true
        }
    }
}
