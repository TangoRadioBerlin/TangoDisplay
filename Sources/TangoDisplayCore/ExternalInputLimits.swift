import Foundation

/// Size bounds for responses read from external processes/services (JRiver MCWS
/// over localhost, osascript stdout). A compromised or buggy source returning a
/// pathologically large payload must not be parsed into an even larger String.
///
/// Note: the convenience APIs in use (`URLSession.shared.data`, `readDataToEndOfFile`)
/// already buffer the full payload before we see it, so this caps the *parsing*
/// amplification, not the initial receive. A true streaming cap would need a
/// delegate-based session / incremental reads — out of scope for this localhost-only,
/// low-severity hardening.
public enum ExternalInputLimits {
    /// Generous upper bound; real now-playing/playlist responses are far smaller.
    public static let maxResponseBytes = 16 * 1024 * 1024  // 16 MiB

    public static func isWithinLimit(_ byteCount: Int) -> Bool {
        byteCount <= maxResponseBytes
    }
}
