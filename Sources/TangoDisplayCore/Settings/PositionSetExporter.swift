import Foundation

/// Encodes/decodes a single scene's position override (`PositionSet`) for user-driven save/load.
///
/// The format is the model's own Codable JSON, so a saved set keeps loading through the same
/// decoding as the profile store. This lets the DJ back up a genre's positions or copy one
/// genre's layout onto another by saving from one scene and loading into another.
public enum PositionSetExporter {

    public static func exportData(_ set: PositionSet) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(set)
    }

    public static func importPositionSet(from data: Data) throws -> PositionSet {
        try JSONDecoder().decode(PositionSet.self, from: data)
    }
}
