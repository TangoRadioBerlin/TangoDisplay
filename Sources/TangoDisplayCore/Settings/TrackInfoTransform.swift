import Foundation

/// A track metadata field that the display can show and that the user can transform.
public enum TrackInfoField: String, CaseIterable, Codable, Identifiable {
    case artist
    case title
    case year
    case albumArtist
    case comments
    case grouping

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .artist:      return "Artist"
        case .title:       return "Title"
        case .year:        return "Year"
        case .albumArtist: return "Album Artist"
        case .comments:    return "Comments"
        case .grouping:    return "Grouping"
        }
    }

    public var sampleValue: String {
        switch self {
        case .artist:      return "Osvaldo Fresedo"
        case .title:       return "Arrabalero - 440 Hz"
        case .year:        return "1939"
        case .albumArtist: return "Osvaldo Fresedo"
        case .comments:    return "instrumental"
        case .grouping:    return "Vals"
        }
    }

    /// The raw value of this field on a given track (empty string when absent).
    public func rawValue(from track: Track) -> String {
        switch self {
        case .artist:      return track.artist
        case .title:       return track.title
        case .year:        return track.year.map(String.init) ?? ""
        case .albumArtist: return track.albumArtist ?? ""
        case .comments:    return track.comment ?? ""
        case .grouping:    return track.grouping ?? ""
        }
    }
}

/// A per-field display rule: optionally take the value from another field, then optionally apply a regex.
/// `sourceField` is absent in older persisted data → decodes to nil (no remap).
public struct TransformRule: Codable, Equatable {
    public var enabled: Bool
    public var pattern: String
    public var replacement: String
    public var testInput: String
    /// When set, the field's value is taken from this source field BEFORE the regex is applied
    /// (e.g. fill "Album Artist" with the content of "Artist").
    public var sourceField: TrackInfoField?

    public init(enabled: Bool = false, pattern: String = "", replacement: String = "",
                testInput: String = "", sourceField: TrackInfoField? = nil) {
        self.enabled = enabled
        self.pattern = pattern
        self.replacement = replacement
        self.testInput = testInput
        self.sourceField = sourceField
    }
}

/// Resolves the display value for `field` on `track`, applying any matching rule in `rules`:
/// 1. If the rule sets `sourceField`, read that field's raw value instead of `field`'s own.
/// 2. If the rule is enabled with a non-empty pattern, apply the regex transform.
/// Returns the raw (possibly remapped) value when no transform applies.
public func resolveTrackField(_ field: TrackInfoField,
                              from track: Track,
                              rules: [String: TransformRule]) -> String {
    let rule = rules[field.rawValue]
    let base = (rule?.sourceField ?? field).rawValue(from: track)
    guard let rule, rule.enabled, !rule.pattern.isEmpty else { return base }
    return applyRegexTransform(base, pattern: rule.pattern, replacement: rule.replacement)
}
