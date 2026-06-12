import Foundation

/// What happens to a plugin slot when its rule's genre/year condition matches the current track.
public enum SlotRuleAction: String, Codable, CaseIterable {
    case activate   // active when matched, bypassed otherwise
    case bypass     // bypassed when matched, active otherwise
}

/// Direction of the year threshold. The threshold year itself belongs to the "younger" side.
public enum YearComparison: String, Codable, CaseIterable {
    case olderThan        // track year strictly before the threshold
    case fromYearOnwards  // track year at or after the threshold
}

/// How the genre and year conditions combine.
public enum MatchMode: String, Codable, CaseIterable {
    case all   // genre AND year
    case any   // genre OR year

    public var displayName: String {
        switch self {
        case .all: "Genre AND Year"
        case .any: "Genre OR Year"
        }
    }
}

/// Per-slot rule that automatically activates or bypasses a plugin based on the current track's
/// genre and/or year. Genre and year conditions are both optional and combined with AND
/// (an empty/absent condition always matches).
public struct AutoBypassRule: Codable, Equatable {
    /// Genres to match (case-insensitive, exact or word-boundary partial). Empty = any genre.
    public var matchGenres: [String]
    /// Year threshold; nil = no year condition.
    public var yearThreshold: Int?
    /// Only relevant when `yearThreshold != nil`.
    public var yearMode: YearComparison
    /// What to do with the slot when the conditions match.
    public var action: SlotRuleAction
    /// How the genre and year conditions combine (AND / OR). Default AND.
    public var matchMode: MatchMode

    public init(matchGenres: [String] = [],
                yearThreshold: Int? = nil,
                yearMode: YearComparison = .olderThan,
                action: SlotRuleAction = .activate,
                matchMode: MatchMode = .all) {
        self.matchGenres = matchGenres
        self.yearThreshold = yearThreshold
        self.yearMode = yearMode
        self.action = action
        self.matchMode = matchMode
    }

    // Tolerant decoding so older saved rules (without matchMode) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchGenres   = try c.decodeIfPresent([String].self, forKey: .matchGenres) ?? []
        yearThreshold = try c.decodeIfPresent(Int.self, forKey: .yearThreshold)
        yearMode      = try c.decodeIfPresent(YearComparison.self, forKey: .yearMode) ?? .olderThan
        action        = try c.decodeIfPresent(SlotRuleAction.self, forKey: .action) ?? .activate
        matchMode     = try c.decodeIfPresent(MatchMode.self, forKey: .matchMode) ?? .all
    }

    /// True when the track's genre satisfies the genre condition. Empty list → always true.
    /// Matching mirrors CortinaDetector: trim + lowercase, exact OR word-boundary substring.
    public func genreMatches(_ trackGenre: String) -> Bool {
        guard !matchGenres.isEmpty else { return true }
        let needle = trackGenre.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return false }
        for raw in matchGenres {
            let key = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if key.isEmpty { continue }
            if needle == key { return true }
            if needle.hasPrefix(key + " ") || needle.contains(" " + key) { return true }
        }
        return false
    }

    /// True when the track's year satisfies the year condition. No threshold → always true.
    /// A missing year counts as "younger": it satisfies `.fromYearOnwards` and fails `.olderThan`.
    public func yearMatches(_ year: Int?) -> Bool {
        guard let threshold = yearThreshold else { return true }
        switch yearMode {
        case .olderThan:       return year != nil && year! < threshold
        case .fromYearOnwards: return year == nil || year! >= threshold
        }
    }

    /// Whether the slot should be active for the given track, after applying the rule's action.
    public func shouldBeActive(genre: String, year: Int?) -> Bool {
        let matched: Bool
        switch matchMode {
        case .all:
            // Empty conditions always match, AND-combined.
            matched = genreMatches(genre) && yearMatches(year)
        case .any:
            // Only conditions that are actually set contribute, OR-combined.
            let genreActive = !matchGenres.isEmpty
            let yearActive = yearThreshold != nil
            let genreHit = genreActive && genreMatches(genre)
            let yearHit = yearActive && yearMatches(year)
            matched = (!genreActive && !yearActive) ? false : (genreHit || yearHit)
        }
        switch action {
        case .activate: return matched
        case .bypass:   return !matched
        }
    }
}
