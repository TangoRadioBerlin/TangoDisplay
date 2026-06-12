import Foundation
import Combine

/// Persists user-created appearance profiles as individual JSON files under
/// ~/Library/Application Support/TangoDisplay/profiles/
/// Built-in profiles are never written to disk; they are synthesised at runtime.
public final class ProfileStore: ObservableObject {
    @Published public var userProfiles: [AppearanceProfile] = []

    /// Files in the store that could not be decoded on the last `load()`.
    /// The originals are never modified or deleted; a copy is placed in
    /// `profiles/unloadable/` so the data survives any later rewrite.
    @Published public private(set) var loadFailures: [ProfileLoadFailure] = []

    private let storeURL: URL

    public init(storeURL: URL? = nil) {
        if let url = storeURL {
            self.storeURL = url
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.storeURL = appSupport
                .appendingPathComponent("TangoDisplay", isDirectory: true)
                .appendingPathComponent("profiles", isDirectory: true)
        }
    }

    // MARK: - Image storage

    /// Directory where per-profile background images are stored.
    public var imagesDirectoryURL: URL {
        storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("images", isDirectory: true)
    }

    /// Full URL for a stored image filename (e.g. "{uuid}.jpg").
    public func imageURL(for filename: String) -> URL {
        imagesDirectoryURL.appendingPathComponent(filename)
    }

    /// Creates the images directory if it doesn't already exist.
    public func createImagesDirectoryIfNeeded() {
        let url = imagesDirectoryURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public var allProfiles: [AppearanceProfile] {
        AppearanceProfile.builtIns + userProfiles
    }

    // MARK: - Load

    public func load() {
        createDirectoryIfNeeded()
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: storeURL,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" && !$0.hasDirectoryPath }
        } catch {
            files = []
        }

        let decoder = JSONDecoder()
        var loaded: [AppearanceProfile] = []
        var failures: [ProfileLoadFailure] = []
        for url in files {
            do {
                let data = try Data(contentsOf: url)
                let profile = try decoder.decode(AppearanceProfile.self, from: data)
                guard !profile.isBuiltIn else { continue }
                loaded.append(profile)
            } catch {
                failures.append(ProfileLoadFailure(fileURL: url,
                                                   message: String(describing: error)))
                quarantineCopy(of: url)
            }
        }
        userProfiles = loaded.sorted { $0.name < $1.name }
        loadFailures = failures
    }

    /// Directory holding copies of files that failed to decode.
    public var quarantineDirectoryURL: URL {
        storeURL.appendingPathComponent("unloadable", isDirectory: true)
    }

    /// Copies an unloadable file into the quarantine directory (never moves or
    /// deletes the original). Best-effort: failures here must not block loading.
    private func quarantineCopy(of url: URL) {
        let dir = quarantineDirectoryURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try? FileManager.default.copyItem(at: url, to: dest)
    }

    // MARK: - Save

    public func save(_ profile: AppearanceProfile) throws {
        guard !profile.isBuiltIn else {
            throw ProfileStoreError.cannotModifyBuiltIn
        }
        createDirectoryIfNeeded()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profile)
        let fileURL = storeURL.appendingPathComponent("\(profile.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)

        // Update in-memory list
        if let idx = userProfiles.firstIndex(where: { $0.id == profile.id }) {
            userProfiles[idx] = profile
        } else {
            userProfiles.append(profile)
            userProfiles.sort { $0.name < $1.name }
        }
    }

    // MARK: - Delete

    public func delete(_ profile: AppearanceProfile) throws {
        guard !profile.isBuiltIn else {
            throw ProfileStoreError.cannotModifyBuiltIn
        }
        let fileURL = storeURL.appendingPathComponent("\(profile.id.uuidString).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        // Clean up any associated background images
        if let filename = profile.backgroundImageFilename {
            try? FileManager.default.removeItem(at: imageURL(for: filename))
        }
        for entry in profile.artistBackgrounds {
            if let filename = entry.imageFilename {
                try? FileManager.default.removeItem(at: imageURL(for: filename))
            }
        }
        userProfiles.removeAll { $0.id == profile.id }
    }

    // MARK: - Draft persistence

    /// Where unsaved working-copy edits are persisted so they survive an app
    /// restart (updates always force one). Lives next to the profiles folder.
    public var draftURL: URL {
        storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("draft-profile.json")
    }

    /// Persists the in-progress (unsaved) working profile. Unlike `save(_:)`,
    /// built-ins are allowed here — a draft is exactly the case of editing one.
    public func saveDraft(_ profile: AppearanceProfile) throws {
        let parent = draftURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try? FileManager.default.createDirectory(at: parent,
                                                     withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try encoder.encode(profile).write(to: draftURL, options: .atomic)
    }

    /// Returns the persisted draft, or nil when there is none or it can't be
    /// decoded (a corrupt draft must never block app start).
    public func loadDraft() -> AppearanceProfile? {
        guard let data = try? Data(contentsOf: draftURL) else { return nil }
        return try? JSONDecoder().decode(AppearanceProfile.self, from: data)
    }

    public func clearDraft() {
        try? FileManager.default.removeItem(at: draftURL)
    }

    // MARK: - Helpers

    private func createDirectoryIfNeeded() {
        guard !FileManager.default.fileExists(atPath: storeURL.path) else { return }
        try? FileManager.default.createDirectory(at: storeURL,
                                                  withIntermediateDirectories: true)
    }
}

/// Describes a profile file that could not be decoded during `load()`.
public struct ProfileLoadFailure: Equatable {
    public let fileURL: URL
    public let message: String

    public init(fileURL: URL, message: String) {
        self.fileURL = fileURL
        self.message = message
    }
}

public enum ProfileStoreError: Error, LocalizedError {
    case cannotModifyBuiltIn

    public var errorDescription: String? {
        switch self {
        case .cannotModifyBuiltIn: "Built-in profiles cannot be modified or deleted."
        }
    }
}
