import Foundation

/// Pure helpers for matching an arbitrary hex colour to a fixed palette. Used to map a configured
/// genre colour (free-form hex) onto the setlist's fixed tag-colour palette.
public enum ColorMatching {

    /// Parses "#RRGGBB" or "RRGGBB" (case-insensitive) into 0…255 components. nil if unparseable.
    public static func rgb(fromHex hex: String) -> (r: Int, g: Int, b: Int)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        return (r: (value >> 16) & 0xFF, g: (value >> 8) & 0xFF, b: value & 0xFF)
    }

    /// Index of the palette entry nearest to `hex` by squared RGB distance. Palette entries that
    /// don't parse are skipped. Returns nil when `hex` is invalid or no palette entry parses.
    public static func nearestIndex(toHex hex: String, palette: [String]) -> Int? {
        guard let target = rgb(fromHex: hex) else { return nil }
        var best: (index: Int, dist: Int)?
        for (i, entry) in palette.enumerated() {
            guard let c = rgb(fromHex: entry) else { continue }
            let dr = c.r - target.r, dg = c.g - target.g, db = c.b - target.b
            let dist = dr * dr + dg * dg + db * db
            if best == nil || dist < best!.dist { best = (i, dist) }
        }
        return best?.index
    }
}
