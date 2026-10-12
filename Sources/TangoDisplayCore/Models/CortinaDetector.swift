import Foundation

public struct CortinaDetector {
    public var useAllowlist: Bool
    public var allowlistGenres: Set<String>         // pre-lowercased cortina genres
    public var allowlistPartialGenres: Set<String>  // pre-lowercased allowlist genres that also use substring matching
    public var useDenylist: Bool
    public var denylistGenres: Set<String>          // pre-lowercased dance genres (inverted logic)
    public var denylistPartialGenres: Set<String>   // pre-lowercased genres that also use substring matching

    public init(useAllowlist: Bool, allowlistGenres: Set<String>,
                allowlistPartialGenres: Set<String> = [],
                useDenylist: Bool, denylistGenres: Set<String>,
                denylistPartialGenres: Set<String> = []) {
        self.useAllowlist = useAllowlist
        self.allowlistGenres = allowlistGenres
        self.allowlistPartialGenres = allowlistPartialGenres
        self.useDenylist = useDenylist
        self.denylistGenres = denylistGenres
        self.denylistPartialGenres = denylistPartialGenres
    }

    /// A genre "is" one of `genres`: exactly (or via a built-in alias such as
    /// Milongón → Milonga), or by containment for keys in `partial` — see `GenreMatching`.
    private static func matches(_ genre: String, exact genres: Set<String>, partial: Set<String>) -> Bool {
        genres.contains { GenreMatching.matchesExactly(genre: genre, key: $0) }
            || partial.contains { GenreMatching.contains(genre: genre, key: $0) }
    }

    /// Returns true if the genre indicates this track is a cortina.
    /// Empty genre returns true under denylist rule (not in dance-genres set).
    public func isCortina(genre: String) -> Bool {
        if useAllowlist, Self.matches(genre, exact: allowlistGenres, partial: allowlistPartialGenres) {
            return true
        }
        if useDenylist, !Self.matches(genre, exact: denylistGenres.union(denylistPartialGenres),
                                      partial: denylistPartialGenres) {
            return true
        }
        return false
    }
}
