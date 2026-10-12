import Foundation

/// The one genre-keyword matcher behind cortina rules, scene resolution, display-label
/// overrides and plugin rules. A configured key ("Vals", "Milonga", "Tango") matches a
/// track genre when it is the genre, or — for keys in the partial set — when it appears
/// anywhere in it: "Tango Vals", "Tango-Vals", "Tango: Milonga", "Vals Criollo". No
/// word-boundary requirement; comparison is case- and diacritic-insensitive.
///
/// Built-in aliases cover spellings that are the same dance but not a substring:
/// "Milongón" / "Milongon" is a Milonga.
public enum GenreMatching {

    /// Alternative spellings a key also stands for, keyed and valued in normalized form.
    public static let aliases: [String: [String]] = ["milonga": ["milongon"]]

    /// Trimmed, lowercased, diacritics folded ("Milongón" → "milongon").
    public static func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
    }

    private static func needles(forNormalizedKey k: String) -> [String] {
        [k] + (aliases[k] ?? [])
    }

    /// The genre IS the key (or one of its aliases).
    public static func matchesExactly(genre: String, key: String) -> Bool {
        let g = normalized(genre), k = normalized(key)
        guard !g.isEmpty, !k.isEmpty else { return false }
        return needles(forNormalizedKey: k).contains(g)
    }

    /// The key (or one of its aliases) appears anywhere in the genre.
    public static func contains(genre: String, key: String) -> Bool {
        let g = normalized(genre), k = normalized(key)
        guard !g.isEmpty, !k.isEmpty else { return false }
        return needles(forNormalizedKey: k).contains { g.range(of: $0) != nil }
    }

    /// Start offset of the rightmost occurrence of the key (or an alias) in the genre.
    private static func rightmostHit(normalizedGenre g: String, normalizedKey k: String) -> Int? {
        var best: Int?
        for needle in needles(forNormalizedKey: k) {
            guard let r = g.range(of: needle, options: .backwards) else { continue }
            let pos = g.distance(from: g.startIndex, to: r.lowerBound)
            if best.map({ pos > $0 }) ?? true { best = pos }
        }
        return best
    }

    /// Which of `keys` a genre resolves to. An exact hit wins outright; otherwise, among
    /// the keys in `partialKeys` that appear in the genre, the one whose occurrence starts
    /// furthest right wins — "Tango Vals" is a Vals, "Tango: Milonga" a Milonga. Returns
    /// the key as listed in `keys` (original spelling) so callers can use it as a lookup.
    public static func bestMatch(genre: String, keys: [String], partialKeys: Set<String>) -> String? {
        let g = normalized(genre)
        guard !g.isEmpty else { return nil }
        let partial = Set(partialKeys.map(normalized))
        var best: (key: String, pos: Int)?
        for key in keys {
            let k = normalized(key)
            guard !k.isEmpty else { continue }
            if needles(forNormalizedKey: k).contains(g) { return key }
            guard partial.contains(k), let pos = rightmostHit(normalizedGenre: g, normalizedKey: k) else { continue }
            if best.map({ pos > $0.pos }) ?? true { best = (key, pos) }
        }
        return best?.key
    }
}
