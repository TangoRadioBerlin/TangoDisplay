import Foundation

/// Persistence codec for genre lists (allow-/denylist and partial-match sets).
///
/// Historically these were stored as comma-joined strings, which is ambiguous
/// because a comma is a valid genre character ("Foxtrot, slow" split into two
/// broken entries). Storage is now a JSON array; the legacy comma format is
/// still read once for migration and rewritten as JSON on the next save.
public enum GenreListCodec {

    /// Encode a genre list for UserDefaults storage. An empty list encodes as
    /// `[]` — deliberately distinct from "no value stored".
    public static func encode(_ list: [String]) -> Data? {
        try? JSONEncoder().encode(list)
    }

    /// Decode a stored genre list.
    ///
    /// Preference order: JSON `data` (even an empty array) → legacy comma
    /// string (one-time migration; also the fallback for corrupt data) →
    /// `defaultValue`.
    public static func decode(data: Data?, legacyCommaString: String?, default defaultValue: [String]) -> [String] {
        if let data, let list = try? JSONDecoder().decode([String].self, from: data) {
            return list
        }
        return parseLegacy(legacyCommaString, default: defaultValue)
    }

    /// Parse the legacy comma-joined format. nil/empty → default.
    public static func parseLegacy(_ raw: String?, default defaultValue: [String]) -> [String] {
        guard let raw, !raw.isEmpty else { return defaultValue }
        return raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
