import Foundation

public enum AppearanceProfileResolution {
    /// Resolves the active profile from a collection, preserving the current
    /// value when the active ID exists but is temporarily absent from the list.
    ///
    /// - ID set and found → returns the found profile.
    /// - ID set but NOT found (transient lookup miss) → returns `current` unchanged.
    /// - ID nil (no active selection) → returns `.classic`.
    public static func resolve(
        activeID: UUID?,
        in all: [AppearanceProfile],
        current: AppearanceProfile
    ) -> AppearanceProfile {
        guard let id = activeID else { return .classic }
        if let found = all.first(where: { $0.id == id }) { return found }
        return current
    }
}
