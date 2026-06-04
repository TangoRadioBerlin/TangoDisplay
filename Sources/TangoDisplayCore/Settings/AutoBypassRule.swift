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

    public init(matchGenres: [String] = [],
                yearThreshold: Int? = nil,
                yearMode: YearComparison = .olderThan,
                action: SlotRuleAction = .activate) {
        self.matchGenres = matchGenres
        self.yearThreshold = yearThreshold
        self.yearMode = yearMode
        self.action = action
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
        let matched = genreMatches(genre) && yearMatches(year)
        switch action {
        case .activate: return matched
        case .bypass:   return !matched
        }
    }
}
