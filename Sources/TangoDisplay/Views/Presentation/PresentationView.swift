import AppKit
import SwiftUI
import TangoDisplayCore

struct PresentationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    var isPreview: Bool = false

    @State private var bgImage: NSImage? = nil
    @State private var artistBgImage: NSImage? = nil
    @State private var genreBgImage: NSImage? = nil
    @State private var performanceBgImage: NSImage? = nil

    private var activeProfile: AppearanceProfile {
        if let draft = appState.draftProfile { return draft }
        let all = appState.profileStore.allProfiles
        if let id = appState.settings.activeProfileID,
           let found = all.first(where: { $0.id == id }) {
            return found
        }
        return AppearanceProfile.classic
    }

    private var shouldShowArtwork: Bool {
        // While editing positions in the preview, show a placeholder so artwork position/size is visible.
        if isPreview, appState.showElementBoundsInPreview { return activeProfile.showArtworkDance }
        // Mirrored presentation screen follows the simulated scene's mode.
        let mode = isMirroring ? effectiveDisplayState.mode : appState.displayState.mode
        switch mode {
        case .playing: return activeProfile.showArtworkDance
        case .cortina: return activeProfile.showArtworkCortina
        default:       return false
        }
    }

    var body: some View {
        // Content layer: transitions between playing/idle/cortina views.
        // Background is applied behind it; track counter is overlaid on top.
        ZStack {
            // Album artwork layer — above background, below text.
            // Uses displayedArtworkTrackID as transition identity so it
            // transitions in/out with each track change (same timing as text).
            if shouldShowArtwork {
                TransitionContainer(
                    identity: appState.displayedArtworkTrackID,
                    style: activeProfile.transitionStyle,
                    duration: activeProfile.transitionDuration
                ) {
                    GeometryReader { geo in
                        // Artwork offsets are percentages of the resolution → resolve to points here.
                        let ax = renderProfile.albumArtworkOffsetX / 100 * geo.size.width
                        let ay = renderProfile.albumArtworkOffsetY / 100 * geo.size.height
                        // Square backing plate: sized off the artwork's displayed square (min screen
                        // dimension × artwork scale), up to 25% larger, centred on the same offset.
                        let artworkSide = min(geo.size.width, geo.size.height) * renderProfile.albumArtworkScale
                        let backingSide = artworkSide * renderProfile.albumArtworkBackingScale
                        ZStack {
                        if renderProfile.albumArtworkBackingEnabled {
                            Rectangle()
                                .fill(renderProfile.albumArtworkBackingSwiftUIColor)
                                .frame(width: backingSide, height: backingSide)
                                .mask(fadeMask(fade: renderProfile.albumArtworkBackingEdgeFade,
                                               style: renderProfile.albumArtworkBackingFadeStyle))
                                .opacity(renderProfile.albumArtworkBackingOpacity)
                                .offset(x: ax, y: ay)
                        }
                        Group {
                            if let art = appState.currentArtwork {
                                Image(nsImage: art)
                                    .resizable()
                                    .scaledToFit()
                                    .mask(fadeMask(fade: renderProfile.albumArtworkEdgeFade,
                                                   style: renderProfile.albumArtworkFadeStyle))
                                    .scaleEffect(renderProfile.albumArtworkScale)
                                    .offset(x: ax, y: ay)
                                    .opacity(renderProfile.albumArtworkOpacity)
                            } else if isPreview, appState.showElementBoundsInPreview {
                                // Artwork positioning placeholder (no real artwork in the preview).
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.accentColor.opacity(0.8),
                                                          style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                                    )
                                    .overlay(Image(systemName: "music.note")
                                        .font(.system(size: 120))
                                        .foregroundColor(.white.opacity(0.5)))
                                    .aspectRatio(1, contentMode: .fit)
                                    .padding(60)
                                    .scaleEffect(renderProfile.albumArtworkScale)
                                    .offset(x: ax, y: ay)
                                    .opacity(renderProfile.albumArtworkOpacity)
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                }
            }

            TransitionContainer(
                identity: appState.displayState,
                style: activeProfile.transitionStyle,
                duration: activeProfile.transitionDuration
            ) {
                GeometryReader { geo in
                    contentView(containerSize: geo.size)
                }
            }

            // Window registration (real display only)
            if !isPreview {
                WindowAccessor { WindowManager.register($0) }
                    .allowsHitTesting(false)
            }
        }
        .background {
            // Rendered behind the content by SwiftUI's layout contract —
            // .background() can never cover its parent view.
            // Priority (performance mode): performance background → background colour.
            // Priority (normal mode): artist background → genre background → profile background → background colour.
            ZStack {
                activeProfile.backgroundSwiftUIColor
                    .ignoresSafeArea()

                let showPerformanceBg = !isSimulatingScene
                    && (appState.displayState.mode == .performance
                        || (appState.displayState.mode == .cortina
                            && appState.displayState.nextTrackIsPerformance
                            && settings.performanceBackgroundDuringCortina))
                if showPerformanceBg {
                    if let img = performanceBgImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                            .ignoresSafeArea()
                    }
                } else if let img = artistBgImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(activeProfile.artistBackgroundScale)
                        .offset(x: activeProfile.artistBackgroundOffsetX,
                                y: activeProfile.artistBackgroundOffsetY)
                        .opacity(activeProfile.artistBackgroundOpacity)
                        .clipped()
                        .ignoresSafeArea()
                } else if let img = genreBgImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(activeProfile.genreBackgroundScale)
                        .offset(x: activeProfile.genreBackgroundOffsetX,
                                y: activeProfile.genreBackgroundOffsetY)
                        .opacity(activeProfile.genreBackgroundOpacity)
                        .clipped()
                        .ignoresSafeArea()
                } else if let img = bgImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(activeProfile.backgroundImageScale)
                        .offset(x: activeProfile.backgroundImageOffsetX,
                                y: activeProfile.backgroundImageOffsetY)
                        .opacity(activeProfile.backgroundImageOpacity)
                        .clipped()
                        .ignoresSafeArea()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            GeometryReader { geo in
                ZStack {
                    ForEach([TrackCounterPosition.topLeft, .topRight, .bottomLeft, .bottomRight],
                            id: \.self) { corner in
                        cornerItems(for: corner, geo: geo)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: corner.overlayAlignment)
                    }
                    // Centred TDJ name outside playing/cortina — those modes render it
                    // inline as a positioned display element instead.
                    let mode = appState.displayState.mode
                    if tdjNameVisible(in: mode), settings.tdjNamePosition == .centre,
                       mode != .playing, mode != .cortina {
                        Text(settings.tdjName)
                            .font(activeProfile.tdjNameFont(geo.size.height))
                            .foregroundColor(activeProfile.tdjNameSwiftUIColor)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            reloadBgImage()
            reloadArtistBgImage()
            reloadGenreBgImage()
            reloadPerformanceBgImage()
        }
        .onChange(of: settings.performanceBackgroundImageFilename) { _ in
            reloadPerformanceBgImage()
        }
        .onChange(of: activeProfile) { _ in
            reloadBgImage()
            reloadArtistBgImage()
            reloadGenreBgImage()
        }
        .onChange(of: appState.displayState.mode) { _ in
            reloadArtistBgImage()
            reloadGenreBgImage()
        }
        .onChange(of: appState.displayState.currentTrack?.artist ?? "") { _ in
            reloadArtistBgImage()
        }
        .onChange(of: appState.displayState.currentTrack?.genre ?? "") { _ in
            reloadGenreBgImage()
        }
        // Scene simulation (preview pane / mirrored screen): reload backgrounds when the selected
        // scene or the simulation state changes so the editor shows each scene's own background.
        .onChange(of: appState.previewScene) { _ in
            reloadGenreBgImage()
            reloadArtistBgImage()
        }
        .onChange(of: appState.showElementBoundsInPreview) { _ in
            reloadGenreBgImage()
            reloadArtistBgImage()
        }
        .onChange(of: appState.mirrorPreviewSceneOnPresentation) { _ in
            reloadGenreBgImage()
            reloadArtistBgImage()
        }
    }

    private func reloadPerformanceBgImage() {
        guard let filename = settings.performanceBackgroundImageFilename else {
            performanceBgImage = nil
            return
        }
        performanceBgImage = NSImage(contentsOf: appState.profileStore.imageURL(for: filename))
    }

    private func tdjNameVisible(in mode: DisplayMode) -> Bool {
        settings.showTdjName && !settings.tdjName.isEmpty
            && settings.tdjNameVisibility.isVisible(in: mode)
    }

    /// Corner overlay shared by the TDJ name and the track counter; when both pick
    /// the same corner they stack. The counter keeps its position-tab offsets.
    @ViewBuilder
    private func cornerItems(for corner: TrackCounterPosition, geo: GeometryProxy) -> some View {
        let mode = appState.displayState.mode
        let showTdj = tdjNameVisible(in: mode) && settings.tdjNamePosition == corner
        let counterPos = settings.showTrackCounter && mode == .playing
            && settings.trackCounterPosition == corner
            ? appState.displayState.tandaPosition : nil
        if showTdj || counterPos != nil {
            VStack(spacing: 12) {
                if showTdj {
                    Text(settings.tdjName)
                        .font(activeProfile.tdjNameFont(geo.size.height))
                        .foregroundColor(activeProfile.tdjNameSwiftUIColor)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                }
                if let pos = counterPos {
                    Text(pos.label)
                        .font(activeProfile.trackCounterFont(geo.size.height))
                        .foregroundColor(activeProfile.trackCounterSwiftUIColor)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                        .offset(x: activeProfile.trackCounterOffsetX / 100 * geo.size.width,
                                y: activeProfile.trackCounterOffsetY / 100 * geo.size.height)
                }
            }
            .padding(24)
        }
    }

    private func reloadBgImage() {
        guard let filename = activeProfile.backgroundImageFilename else {
            bgImage = nil
            return
        }
        let url = appState.profileStore.imageURL(for: filename)
        bgImage = NSImage(contentsOf: url)
    }

    private func reloadArtistBgImage() {
        // Scene simulation doesn't model per-artist backgrounds; the genre/cortina bg wins instead.
        guard !isSimulatingScene else {
            artistBgImage = nil
            return
        }
        guard appState.displayState.mode == .playing else {
            artistBgImage = nil
            return
        }
        let artist = appState.displayState.currentTrack?.artist ?? ""
        guard let match = activeProfile.matchingArtistBackground(for: artist),
              let filename = match.imageFilename else {
            artistBgImage = nil
            return
        }
        artistBgImage = NSImage(contentsOf: appState.profileStore.imageURL(for: filename))
    }

    private func reloadGenreBgImage() {
        let match: GenreBackground?
        if isSimulatingScene {
            // While editing, show the background that belongs to the scene being positioned, so the
            // preview/mirror is WYSIWYG (Dance = profile default → no genre bg; a genre/cortina → its bg).
            switch appState.previewScene {
            case .dance:
                match = nil
            case .genre(let g):
                match = activeProfile.matchingGenreBackground(for: g, using: settings.makeDetector())
            case .cortina:
                match = activeProfile.genreBackgrounds.first { $0.isCortinaEntry }
            }
        } else {
            // Live: active for .playing (dance-genre matches) and .cortina (cortina-sentinel match).
            let mode = appState.displayState.mode
            guard mode == .playing || mode == .cortina else {
                genreBgImage = nil
                return
            }
            let genre = appState.displayState.currentTrack?.genre ?? ""
            match = activeProfile.matchingGenreBackground(for: genre, using: settings.makeDetector())
        }
        guard let match, let filename = match.imageFilename else {
            genreBgImage = nil
            return
        }
        genreBgImage = NSImage(contentsOf: appState.profileStore.imageURL(for: filename))
    }

    /// Sample dance state for the preview, with a chosen genre so the picked scene's
    /// per-genre override resolves against it.
    private static func previewDanceState(genre: String) -> DisplayState {
        DisplayState(
            mode: .playing,
            currentTrack: Track(title: "Sample Title", artist: "Sample Artist", genre: genre,
                                persistentID: "preview-sample", year: 1947,
                                comment: "Sample Singer", albumArtist: "Sample Singer",
                                grouping: "Sample Singer"),
            tandaPosition: TandaPosition(current: 2, total: 4)
        )
    }

    /// Sample cortina state: a cortina track plus the upcoming dance track, so both the
    /// cortina-track section and the "Coming Up" section render in the preview.
    private static let previewCortinaState = DisplayState(
        mode: .cortina,
        currentTrack: Track(title: "Cortina Title", artist: "Cortina Artist", genre: "Cortina",
                            persistentID: "preview-cortina"),
        nextTrack: Track(title: "Next Title", artist: "Next Artist", genre: "Tango",
                         persistentID: "preview-next", year: 1947,
                         comment: "Sample Singer", albumArtist: "Sample Singer",
                         grouping: "Sample Singer")
    )

    /// True while the real presentation screen should mirror the selected preview scene: the
    /// Position tab is open (a draft is active) and the maintainer enabled mirroring.
    private var isMirroring: Bool {
        !isPreview && appState.mirrorPreviewSceneOnPresentation && appState.draftProfile != nil
    }

    /// True whenever the view is showing a simulated scene sample: the preview pane while the
    /// Position tab is open (always follows the Scene selection, regardless of what is playing),
    /// or the mirrored presentation screen. Drives scene-aware background selection.
    private var isSimulatingScene: Bool {
        if isMirroring { return true }
        return isPreview && appState.showElementBoundsInPreview
    }

    private func sampleState(for scene: PreviewScene) -> DisplayState {
        switch scene {
        case .dance:        return Self.previewDanceState(genre: "Tango")
        case .genre(let g): return Self.previewDanceState(genre: g)
        case .cortina:      return Self.previewCortinaState
        }
    }

    /// In the preview pane (whenever the Position tab is open) and on the mirrored presentation
    /// screen, inject a sample for the selected scene so positioning is visible. Otherwise live state.
    private var effectiveDisplayState: DisplayState {
        if isSimulatingScene { return sampleState(for: appState.previewScene) }
        return appState.displayState
    }

    private static let previewSampleLastPlayed = Track(
        title: "Previous Title", artist: "Previous Artist", genre: "Tango", persistentID: "preview-last")

    private var effectiveLastPlayed: Track? {
        if isSimulatingScene { return Self.previewSampleLastPlayed }
        return appState.lastPlayedTrack
    }

    /// The active profile with the selected scene's position override applied (dance = base,
    /// genre/cortina = that entry's sparse override). Shared by the preview pane and the mirror.
    private func profileForScene(_ scene: PreviewScene) -> AppearanceProfile {
        switch scene {
        case .dance:
            return activeProfile   // profile defaults, no override
        case .genre(let g):
            return activeProfile.applyingPositionOverride(
                activeProfile.positionOverride(forGenre: g, using: appState.settings.makeDetector()))
        case .cortina:
            // Gate on genreBackgroundsEnabled so the preview/mirror match runtime, where the
            // cortina override is only applied when genre backgrounds are enabled.
            guard activeProfile.genreBackgroundsEnabled else { return activeProfile }
            let set = activeProfile.genreBackgrounds.first { $0.isCortinaEntry }?.positions
            return activeProfile.applyingPositionOverride(set)
        }
    }

    /// Profile with the per-genre / cortina position override applied. Used for both the artwork
    /// layer and the text views. The preview and the mirrored presentation screen apply the SAME
    /// override as runtime for the selected scene, so configuring positions is WYSIWYG everywhere.
    private var renderProfile: AppearanceProfile {
        if isMirroring { return profileForScene(appState.previewScene) }
        if isPreview {
            guard appState.showElementBoundsInPreview else { return activeProfile }
            return profileForScene(appState.previewScene)
        }
        return activeProfile.applyingPositionOverride(
            activeProfile.positionOverride(forGenre: effectiveDisplayState.currentTrack?.genre ?? "",
                                           using: appState.settings.makeDetector()))
    }

    @ViewBuilder
    private func contentView(containerSize: CGSize) -> some View {
        let showBounds = isPreview && appState.showElementBoundsInPreview
        let state = effectiveDisplayState
        // renderProfile carries any per-genre-background override (text positions + artwork).
        switch state.mode {
        case .playing:
            PlayingView(
                state: state,
                profile: renderProfile,
                isLastTandaActive: appState.isLastTandaActive,
                settings: appState.settings,
                lastPlayedTrack: effectiveLastPlayed,
                showBounds: showBounds,
                containerSize: containerSize
            )
        case .cortina:
            CortinaView(
                state: state,
                profile: renderProfile,
                isLastTandaActive: appState.isLastTandaActive,
                settings: appState.settings,
                lastPlayedTrack: effectiveLastPlayed,
                showBounds: showBounds,
                containerSize: containerSize
            )
        case .idle, .paused:
            IdleView(
                mode: state.mode,
                settings: appState.settings,
                profile: activeProfile,
                containerSize: containerSize
            )
        case .performance:
            PerformanceView(
                currentTrack: appState.displayState.currentTrack,
                settings: appState.settings
            )
        case .override:
            overrideView(containerSize: containerSize)
        }
    }

    @ViewBuilder
    private func fadeMask(fade: Double, style: AlbumArtFadeStyle) -> some View {
        switch style {
        case .radial: edgeFadeMask(fade: fade)
        case .edges:  linearEdgeFadeMask(fade: fade)
        }
    }

    /// Rectangular edge fade: opaque centre fading to transparent toward all four straight edges
    /// (intersection of a horizontal and a vertical linear gradient).
    private func linearEdgeFadeMask(fade: Double) -> some View {
        let inset = max(0.0, min(0.5, fade * 0.5))
        let stops: [Gradient.Stop] = [
            .init(color: .white.opacity(0), location: 0),
            .init(color: .white, location: inset),
            .init(color: .white, location: 1 - inset),
            .init(color: .white.opacity(0), location: 1)
        ]
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
            .mask(LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom))
    }

    private func edgeFadeMask(fade: Double) -> some View {
        GeometryReader { geo in
            // Reach the *corner* of the (square) artwork, not just the
            // inscribed circle — otherwise the square's corners fall outside
            // the gradient and disappear instantly at any non-zero fade.
            let r = sqrt(geo.size.width * geo.size.width
                       + geo.size.height * geo.size.height) * 0.5
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .white,             location: 0.0),
                    .init(color: .white,             location: max(0.0, 1.0 - fade)),
                    .init(color: .white.opacity(0),  location: 1.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: r
            )
        }
    }

    private func overrideView(containerSize: CGSize) -> some View {
        Text(appState.displayState.overrideText ?? "")
            .font(activeProfile.overrideTextFont(containerSize.height))
            .foregroundColor(activeProfile.overrideTextSwiftUIColor)
            .multilineTextAlignment(.center)
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
