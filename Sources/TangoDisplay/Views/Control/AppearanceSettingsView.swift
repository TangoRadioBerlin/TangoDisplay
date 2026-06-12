import AppKit
import SwiftUI
import TangoDisplayCore
import UniformTypeIdentifiers

private enum AppearanceTab: CaseIterable {
    case visibility, text, position, colours, artworkTransition, cortina, lastTanda

    var displayName: String {
        switch self {
        case .visibility:         return "Visibility"
        case .text:               return "Text"
        case .position:           return "Position"
        case .colours:            return "Colours"
        case .artworkTransition:  return "Artwork & Motion"
        case .cortina:            return "Cortina"
        case .lastTanda:          return "Last Tanda"
        }
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings

    @State private var selectedTab: AppearanceTab = .visibility
    @State private var working: AppearanceProfile = .classic
    @State private var savedWorking: AppearanceProfile = .classic
    @State private var showingSaveSheet = false
    @State private var newProfileName = ""
    @State private var didSave = false
    @State private var bgThumbnail: NSImage? = nil
    @State private var artistBgThumbnails: [UUID: NSImage] = [:]
    @State private var genreBgThumbnails: [UUID: NSImage] = [:]
    @State private var danceDragItem: DisplayTextItem? = nil
    @State private var cortinaTrackDragItem: DisplayTextItem? = nil
    @State private var cortinaUpDragItem: DisplayTextItem? = nil
    @State private var draftSaveWork: DispatchWorkItem? = nil
    @State private var didRestoreDraft = false

    private var workingIsBuiltIn: Bool { working.isBuiltIn }
    private var isDirty: Bool { working != savedWorking }

    private var hasInvalidArtistBackgrounds: Bool {
        guard working.artistBackgroundsEnabled else { return false }
        return working.artistBackgrounds.contains { entry in
            entry.artistName.trimmingCharacters(in: .whitespaces).isEmpty || entry.imageFilename == nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            profileHeader
            Divider()
            tabBar
            Divider()
            contentArea
            Divider()
            saveFooter
        }
        .onAppear {
            loadWorkingCopy()
            restoreDraftIfPresent()
            appState.draftProfile = working
        }
        .onDisappear {
            appState.draftProfile = nil
            appState.hasUnsavedAppearanceChanges = false
        }
        .onChange(of: appState.settings.activeProfileID) { _ in loadWorkingCopy() }
        .onChange(of: settings.denylistGenres) { _ in
            syncGenreBackgroundsToDenylist()
        }
        .onChange(of: working) { _ in
            appState.draftProfile = working
            appState.hasUnsavedAppearanceChanges = isDirty
            scheduleDraftSave()
        }
        .sheet(isPresented: $showingSaveSheet) { saveSheet }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        HStack(spacing: 6) {
            Text("Editing Profile:")
                .foregroundColor(.secondary)
            Text(working.name)
                .fontWeight(.semibold)
            Spacer()
            Button("Save as New Profile…") {
                newProfileName = working.name
                showingSaveSheet = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppearanceTab.allCases, id: \.displayName) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.displayName)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Content area (tab + live preview)

    /// On the Position tab, show a live preview beside the editor so the element boxes/outlines are
    /// visible while positioning (the outlines only render in a visible preview).
    @ViewBuilder
    private var contentArea: some View {
        if selectedTab == .position {
            HSplitView {
                tabContent
                    .frame(minWidth: 360)
                previewColumn
            }
        } else {
            tabContent
        }
    }

    private var previewColumn: some View {
        VStack(spacing: 6) {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)
            PreviewPane()
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Spacer(minLength: 0)
        }
        .frame(minWidth: 280)
        .padding(8)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .visibility:
            AppearanceVisibilityTab(working: $working,
                                    danceDragItem: $danceDragItem,
                                    cortinaTrackDragItem: $cortinaTrackDragItem,
                                    cortinaUpDragItem: $cortinaUpDragItem)
        case .text:
            AppearanceTextTab(working: $working)
        case .position:
            AppearancePositionTab(working: $working)
        case .colours:
            AppearanceColoursTab(working: $working)
        case .artworkTransition:
            AppearanceArtworkTab(working: $working,
                                 bgThumbnail: bgThumbnail,
                                 onPickImage: pickImage,
                                 onClearImage: clearImage,
                                 artistBgThumbnails: artistBgThumbnails,
                                 onPickArtistImage: pickArtistImage(for:),
                                 onClearArtistImage: clearArtistImage(for:),
                                 onAddArtistBackground: addArtistBackground,
                                 onRemoveArtistBackground: removeArtistBackground(_:),
                                 genreBgThumbnails: genreBgThumbnails,
                                 onPickGenreImage: pickGenreImage(for:),
                                 onClearGenreImage: clearGenreImage(for:),
                                 cortinaRowLabel: settings.cortinaLabel)
        case .cortina:
            AppearanceCortinaTab(working: $working)
        case .lastTanda:
            AppearanceLastTandaTab(working: $working)
        }
    }

    // MARK: - Save footer

    private var saveFooter: some View {
        HStack(spacing: 12) {
            if workingIsBuiltIn {
                Text("Saving will create a new custom profile based on \(working.name).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if hasInvalidArtistBackgrounds {
                Label("Each artist entry needs a name and an image.", systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                    .transition(.opacity)
            } else if isDirty {
                Label(didRestoreDraft ? "Restored unsaved changes" : "Unsaved changes",
                      systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .transition(.opacity)
            }
            if didSave {
                Label("Saved!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                    .transition(.opacity)
            }
            Button("Save") { saveProfile() }
                .buttonStyle(.borderedProminent)
                .disabled(hasInvalidArtistBackgrounds)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Save sheet

    private var saveSheet: some View {
        VStack(spacing: 16) {
            Text("Save Profile")
                .font(.headline)

            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { saveNewProfile() }

            HStack {
                Button("Cancel") { showingSaveSheet = false }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])

                Button("Save") { saveNewProfile() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }

    // MARK: - Logic

    private func loadWorkingCopy() {
        let all = appState.profileStore.allProfiles
        if let id = appState.settings.activeProfileID,
           let found = all.first(where: { $0.id == id }) {
            working = found
        } else {
            working = .classic
        }
        savedWorking = working
        appState.hasUnsavedAppearanceChanges = false
        appState.draftProfile = working
        reloadThumbnail()
        reloadArtistBgThumbnails()
        syncGenreBackgroundsToDenylist()
        reloadGenreBgThumbnails()
    }

    private func reloadThumbnail() {
        guard let filename = working.backgroundImageFilename else { bgThumbnail = nil; return }
        let url = appState.profileStore.imageURL(for: filename)
        bgThumbnail = NSImage(contentsOf: url)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a background image"
        guard panel.runModal() == .OK, let src = panel.url else { return }

        let ext = src.pathExtension.isEmpty ? "jpg" : src.pathExtension
        let filename = "\(working.id.uuidString).\(ext)"
        let dest = appState.profileStore.imageURL(for: filename)
        appState.profileStore.createImagesDirectoryIfNeeded()

        if let old = working.backgroundImageFilename, old != filename {
            try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: old))
        }
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try? FileManager.default.copyItem(at: src, to: dest)

        working.backgroundImageFilename = filename
        bgThumbnail = NSImage(contentsOf: dest)
    }

    private func clearImage() {
        if let filename = working.backgroundImageFilename {
            try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: filename))
        }
        working.backgroundImageFilename = nil
        working.backgroundImageOpacity = 1.0
        working.backgroundImageScale = 1.0
        working.backgroundImageOffsetX = 0.0
        working.backgroundImageOffsetY = 0.0
        bgThumbnail = nil
    }

    // MARK: - Artist backgrounds

    private func reloadArtistBgThumbnails() {
        artistBgThumbnails = [:]
        for entry in working.artistBackgrounds {
            guard let filename = entry.imageFilename else { continue }
            let url = appState.profileStore.imageURL(for: filename)
            if let img = NSImage(contentsOf: url) {
                artistBgThumbnails[entry.id] = img
            }
        }
    }

    private func addArtistBackground() {
        working.artistBackgrounds.append(ArtistBackground(artistName: ""))
    }

    private func removeArtistBackground(_ entry: ArtistBackground) {
        if let filename = entry.imageFilename {
            try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: filename))
            artistBgThumbnails.removeValue(forKey: entry.id)
        }
        working.artistBackgrounds.removeAll { $0.id == entry.id }
    }

    private func pickArtistImage(for entry: ArtistBackground) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        let label = entry.artistName.isEmpty ? "this artist" : entry.artistName
        panel.message = "Choose a background image for \(label)"
        guard panel.runModal() == .OK, let src = panel.url else { return }

        let ext = src.pathExtension.isEmpty ? "jpg" : src.pathExtension
        let filename = "artist-\(entry.id.uuidString).\(ext)"
        let dest = appState.profileStore.imageURL(for: filename)
        appState.profileStore.createImagesDirectoryIfNeeded()

        if let old = entry.imageFilename, old != filename {
            try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: old))
        }
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try? FileManager.default.copyItem(at: src, to: dest)

        if let idx = working.artistBackgrounds.firstIndex(where: { $0.id == entry.id }) {
            working.artistBackgrounds[idx].imageFilename = filename
        }
        artistBgThumbnails[entry.id] = NSImage(contentsOf: dest)
    }

    private func clearArtistImage(for entry: ArtistBackground) {
        if let filename = entry.imageFilename {
            try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: filename))
        }
        if let idx = working.artistBackgrounds.firstIndex(where: { $0.id == entry.id }) {
            working.artistBackgrounds[idx].imageFilename = nil
        }
        artistBgThumbnails.removeValue(forKey: entry.id)
    }

    // MARK: - Genre backgrounds

    /// Reconciles `working.genreBackgrounds` against the current denylist. Rows are not user-managed
    /// here — the per-genre rows mirror Cortina-Rules denylist entries, plus exactly one cortina
    /// sentinel row (genreKey == "") for non-dance tracks.
    private func syncGenreBackgroundsToDenylist() {
        let desired = settings.denylistGenres
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var updated = working.genreBackgrounds

        // Drop dance-genre rows whose key no longer appears in the denylist.
        for entry in updated where !entry.isCortinaEntry {
            if !desired.contains(where: { $0.caseInsensitiveCompare(entry.genreKey) == .orderedSame }) {
                if let filename = entry.imageFilename {
                    try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: filename))
                }
                genreBgThumbnails.removeValue(forKey: entry.id)
            }
        }
        updated.removeAll { entry in
            !entry.isCortinaEntry &&
            !desired.contains(where: { $0.caseInsensitiveCompare(entry.genreKey) == .orderedSame })
        }

        // Append missing denylist entries.
        for key in desired {
            if !updated.contains(where: { !$0.isCortinaEntry && $0.genreKey.caseInsensitiveCompare(key) == .orderedSame }) {
                updated.append(GenreBackground(genreKey: key))
            }
        }

        // Ensure exactly one cortina sentinel row exists.
        let cortinaRows = updated.filter { $0.isCortinaEntry }
        if cortinaRows.isEmpty {
            updated.append(GenreBackground(genreKey: ""))
        } else if cortinaRows.count > 1 {
            // Keep the first; remove duplicates and their files.
            var keptOne = false
            updated = updated.compactMap { entry in
                guard entry.isCortinaEntry else { return entry }
                if !keptOne { keptOne = true; return entry }
                if let filename = entry.imageFilename {
                    try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: filename))
                }
                genreBgThumbnails.removeValue(forKey: entry.id)
                return nil
            }
        }

        if updated != working.genreBackgrounds {
            working.genreBackgrounds = updated
        }
    }

    private func reloadGenreBgThumbnails() {
        genreBgThumbnails = [:]
        for entry in working.genreBackgrounds {
            guard let filename = entry.imageFilename else { continue }
            let url = appState.profileStore.imageURL(for: filename)
            if let img = NSImage(contentsOf: url) {
                genreBgThumbnails[entry.id] = img
            }
        }
    }

    private func pickGenreImage(for entry: GenreBackground) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        let label = entry.isCortinaEntry ? settings.cortinaLabel : entry.genreKey
        panel.message = "Choose a background image for \(label)"
        guard panel.runModal() == .OK, let src = panel.url else { return }

        let ext = src.pathExtension.isEmpty ? "jpg" : src.pathExtension
        let filename = "genre-\(entry.id.uuidString).\(ext)"
        let dest = appState.profileStore.imageURL(for: filename)
        appState.profileStore.createImagesDirectoryIfNeeded()

        if let old = entry.imageFilename, old != filename {
            try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: old))
        }
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try? FileManager.default.copyItem(at: src, to: dest)

        if let idx = working.genreBackgrounds.firstIndex(where: { $0.id == entry.id }) {
            working.genreBackgrounds[idx].imageFilename = filename
        }
        genreBgThumbnails[entry.id] = NSImage(contentsOf: dest)
    }

    private func clearGenreImage(for entry: GenreBackground) {
        if let filename = entry.imageFilename {
            try? FileManager.default.removeItem(at: appState.profileStore.imageURL(for: filename))
        }
        if let idx = working.genreBackgrounds.firstIndex(where: { $0.id == entry.id }) {
            working.genreBackgrounds[idx].imageFilename = nil
        }
        genreBgThumbnails.removeValue(forKey: entry.id)
    }

    private func saveProfile() {
        if workingIsBuiltIn {
            var copy = working
            copy.id = UUID()
            copy.isBuiltIn = false
            try? appState.profileStore.save(copy)
            appState.settings.activeProfileID = copy.id
        } else {
            try? appState.profileStore.save(working)
            savedWorking = working
            appState.hasUnsavedAppearanceChanges = false
            appState.draftProfile = working
        }
        clearDraftState()
        showSaveConfirmation()
    }

    private func saveNewProfile() {
        let trimmed = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var newProfile = working
        newProfile.id = UUID()
        newProfile.name = trimmed
        newProfile.isBuiltIn = false
        try? appState.profileStore.save(newProfile)
        appState.settings.activeProfileID = newProfile.id
        showingSaveSheet = false
        clearDraftState()
    }

    // MARK: - Draft persistence (unsaved edits survive restarts/updates)

    /// Debounced write of the working copy to the on-disk draft, so unsaved
    /// position tweaks survive a quit or an update-forced relaunch.
    private func scheduleDraftSave() {
        draftSaveWork?.cancel()
        guard isDirty else {
            appState.profileStore.clearDraft()
            return
        }
        let snapshot = working
        let store = appState.profileStore
        let work = DispatchWorkItem { try? store.saveDraft(snapshot) }
        draftSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    /// Restores a persisted draft of the currently selected profile (drafts of
    /// other profiles stay on disk untouched until that profile is opened).
    private func restoreDraftIfPresent() {
        guard let draft = appState.profileStore.loadDraft(),
              draft.id == working.id,
              draft != working
        else { return }
        working = draft
        appState.hasUnsavedAppearanceChanges = true
        didRestoreDraft = true
    }

    private func clearDraftState() {
        draftSaveWork?.cancel()
        appState.profileStore.clearDraft()
        didRestoreDraft = false
    }

    private func showSaveConfirmation() {
        withAnimation { didSave = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.didSave = false }
        }
    }
}

// MARK: - Color hexString helper (SwiftUI → hex)

extension Color {
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int((ns.redComponent   * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent  * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
