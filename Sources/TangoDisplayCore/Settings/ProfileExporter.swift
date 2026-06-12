import Foundation

/// Encodes/decodes appearance profiles for user-driven export/import.
///
/// The export format is the store's own on-disk JSON, so any profile file is a
/// valid export and old exports keep importing through the same decode
/// migrations as the store. Background images are referenced by filename only
/// and do not travel with the JSON — import strips the references so a profile
/// never points at images that don't exist on the target machine.
public enum ProfileExporter {

    public static func exportData(_ profile: AppearanceProfile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(profile)
    }

    /// Decodes a profile from exported data and normalises it for this machine:
    /// always a user profile, with a fresh UUID if the ID collides with an
    /// existing or built-in profile, and without image references.
    public static func importProfile(from data: Data,
                                     existingIDs: Set<UUID>) throws -> AppearanceProfile {
        var profile = try JSONDecoder().decode(AppearanceProfile.self, from: data)
        profile.isBuiltIn = false

        let reservedIDs = existingIDs.union(AppearanceProfile.builtIns.map(\.id))
        if reservedIDs.contains(profile.id) {
            profile.id = UUID()
        }

        profile.backgroundImageFilename = nil
        for idx in profile.artistBackgrounds.indices {
            profile.artistBackgrounds[idx].imageFilename = nil
        }
        for idx in profile.genreBackgrounds.indices {
            profile.genreBackgrounds[idx].imageFilename = nil
        }
        return profile
    }
}
