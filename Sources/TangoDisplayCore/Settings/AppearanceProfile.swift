import Foundation

public struct ArtistBackground: Codable, Identifiable, Equatable {
    public var id: UUID
    public var artistName: String      // text to match against track.artist (partial, case-insensitive)
    public var imageFilename: String?  // "artist-{uuid}.{ext}" stored in images dir

    public init(id: UUID = UUID(), artistName: String, imageFilename: String? = nil) {
        self.id = id
        self.artistName = artistName
        self.imageFilename = imageFilename
    }
}

public struct GenreBackground: Codable, Identifiable, Equatable {
    public var id: UUID
    public var genreKey: String        // denylist entry verbatim; empty string is the cortina sentinel
    public var imageFilename: String?  // "genre-{uuid}.{ext}" stored in images dir
    /// Optional per-element position overrides applied while this genre is playing. nil = profile defaults.
    public var positions: PositionSet?

    public init(id: UUID = UUID(), genreKey: String, imageFilename: String? = nil,
                positions: PositionSet? = nil) {
        self.id = id
        self.genreKey = genreKey
        self.imageFilename = imageFilename
        self.positions = positions
    }

    public var isCortinaEntry: Bool { genreKey.isEmpty }
}

public struct AppearanceProfile: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var isBuiltIn: Bool

    public var titleFontName: String
    public var titleFontSize: Double
    public var titleFontBold: Bool
    public var titleFontItalic: Bool
    public var artistFontName: String
    public var artistFontSize: Double
    public var artistFontBold: Bool
    public var artistFontItalic: Bool
    public var genreFontName: String
    public var genreFontSize: Double
    public var genreFontBold: Bool
    public var genreFontItalic: Bool
    public var showYear: Bool
    public var yearFontName: String
    public var yearFontSize: Double
    public var yearFontBold: Bool
    public var yearFontItalic: Bool

    public var backgroundColor: String
    public var titleColor: String
    public var artistColor: String
    public var genreColor: String
    public var yearColor: String
    public var trackCounterColor: String

    public var transitionStyle: TransitionStyle
    public var transitionDuration: Double

    // Background image (optional — nil means no image)
    public var backgroundImageFilename: String?  // "{profileUUID}.{ext}" stored in images dir
    public var backgroundImageOpacity: Double    // 0.0–1.0
    public var backgroundImageScale: Double      // multiplier, 1.0 = fill screen
    public var backgroundImageOffsetX: Double    // points, horizontal pan
    public var backgroundImageOffsetY: Double    // points, vertical pan

    // Artist Backgrounds — per-artist images that override the profile background when the track artist matches
    public var artistBackgroundsEnabled: Bool
    public var artistBackgrounds: [ArtistBackground]
    public var artistBackgroundOpacity: Double
    public var artistBackgroundScale: Double
    public var artistBackgroundOffsetX: Double
    public var artistBackgroundOffsetY: Double

    // Genre Backgrounds — per-genre (and one cortina-only) images that override the profile background.
    // Lower priority than artist backgrounds, higher than the profile image. Driven by AppSettings.denylistGenres.
    public var genreBackgroundsEnabled: Bool
    public var genreBackgrounds: [GenreBackground]
    public var genreBackgroundOpacity: Double
    public var genreBackgroundScale: Double
    public var genreBackgroundOffsetX: Double
    public var genreBackgroundOffsetY: Double

    // Album artwork overlay (shown above background, below text; hidden during cortinas)
    public var showAlbumArtwork: Bool
    public var albumArtworkOpacity: Double   // 0.0–1.0
    public var albumArtworkScale: Double     // multiplier, 1.0 = natural size scaled to fit
    public var albumArtworkOffsetX: Double   // points, horizontal pan
    public var albumArtworkOffsetY: Double   // points, vertical pan
    public var albumArtworkEdgeFade: Double  // 0.0 = no fade, 1.0 = max radial edge fade

    // Configurable vertical order of text items on the display
    public var danceItemOrder: [DisplayTextItem]   // order for dance track display
    public var cortinaItemOrder: [DisplayTextItem] // order for cortina "coming up" section

    // Singer line (displays a track metadata field below the title)
    public var showSinger: Bool
    public var singerSource: SingerSource
    public var showSingerDuringCortina: Bool
    public var singerFontName: String
    public var singerFontSize: Double
    public var singerFontBold: Bool
    public var singerFontItalic: Bool
    public var singerColor: String

    // Per-type field visibility (Dance Track)
    public var showGenreDance:   Bool
    public var showArtistDance:  Bool
    public var showYearDance:    Bool
    public var showTitleDance:   Bool
    public var showSingerDance:  Bool
    public var showArtworkDance: Bool

    // Per-type field visibility (Cortina "Coming Up")
    public var showNextTrackDuringCortina: Bool
    public var showGenreCortina:   Bool
    public var showArtistCortina:  Bool
    public var showYearCortina:    Bool
    public var showTitleCortina:   Bool
    public var showSingerCortina:  Bool
    public var showArtworkCortina: Bool

    // Cortina track display (artist/title of the cortina itself)
    public var showCortinaTrackDuringCortina: Bool
    public var showCortinaTrackArtist: Bool
    public var showCortinaTrackTitle:  Bool
    public var showCortinaTrackYear:   Bool
    public var showCortinaLabel:       Bool

    // Cortina label font/colour (was hardcoded to titleFont + artistColor)
    public var cortinaLabelFontName:   String
    public var cortinaLabelFontSize:   Double
    public var cortinaLabelFontBold:   Bool
    public var cortinaLabelFontItalic: Bool
    public var cortinaLabelColor:      String

    // Cortina track artist font/colour
    public var cortinaArtistFontName:   String
    public var cortinaArtistFontSize:   Double
    public var cortinaArtistFontBold:   Bool
    public var cortinaArtistFontItalic: Bool
    public var cortinaArtistColor:      String

    // Cortina track title font/colour
    public var cortinaTitleFontName:   String
    public var cortinaTitleFontSize:   Double
    public var cortinaTitleFontBold:   Bool
    public var cortinaTitleFontItalic: Bool
    public var cortinaTitleColor:      String

    // Next-up label font/colour (was hardcoded to genreFont + genreColor)
    public var nextUpLabelFontName:   String
    public var nextUpLabelFontSize:   Double
    public var nextUpLabelFontBold:   Bool
    public var nextUpLabelFontItalic: Bool
    public var nextUpLabelColor:      String

    // Idle message font/colour (was hardcoded .system(48, ultraLight) + artistColor.opacity(0.4))
    public var idleMessageFontName:   String
    public var idleMessageFontSize:   Double
    public var idleMessageFontBold:   Bool
    public var idleMessageFontItalic: Bool
    public var idleMessageColor:      String

    // Orderable items for cortina-track section
    public var cortinaTrackItemOrder: [DisplayTextItem]

    // Last Tanda label font/colour
    public var lastTandaLabelFontName:   String
    public var lastTandaLabelFontSize:   Double
    public var lastTandaLabelFontBold:   Bool
    public var lastTandaLabelFontItalic: Bool
    public var lastTandaLabelColor:      String
    public var showLastTandaLabel:       Bool

    // Last Played (previously played track) font/colour + per-mode visibility
    public var lastPlayedFontName:   String
    public var lastPlayedFontSize:   Double
    public var lastPlayedFontBold:   Bool
    public var lastPlayedFontItalic: Bool
    public var lastPlayedColor:      String
    public var showLastPlayedDance:   Bool
    public var showLastPlayedCortina: Bool

    // Genre text casing on the display (uppercase / original / title case)
    public var genreTextCase: GenreTextCase
    // Wrap the year in parentheses, e.g. "(1947)".
    public var yearInParentheses: Bool

    // Album-artwork edge-fade style (radial vs. edges)
    public var albumArtworkFadeStyle: AlbumArtFadeStyle

    // Optional square backing plate rendered behind the album artwork (centred on the same offset).
    public var albumArtworkBackingEnabled: Bool      // draw the backing plate at all
    public var albumArtworkBackingColor: String      // hex colour of the plate
    public var albumArtworkBackingScale: Double      // size relative to the artwork, 1.0–1.25
    public var albumArtworkBackingOpacity: Double     // 0.0–1.0
    public var albumArtworkBackingEdgeFade: Double    // 0.0 = no fade, 1.0 = max edge/corner fade
    public var albumArtworkBackingFadeStyle: AlbumArtFadeStyle  // radial vs. edges

    // Track Counter font
    public var trackCounterFontName:   String
    public var trackCounterFontSize:   Double
    public var trackCounterFontBold:   Bool
    public var trackCounterFontItalic: Bool

    // Override text font/colour
    public var overrideTextFontName:   String
    public var overrideTextFontSize:   Double
    public var overrideTextFontBold:   Bool
    public var overrideTextFontItalic: Bool
    public var overrideTextColor:      String

    // Per-element position offsets (points), analogous to albumArtworkOffsetX/Y.
    // A non-zero X left-aligns that element (see ColorExtension.positioned); 0 keeps it centred.
    // Shared between the dance display and the cortina "coming up" section, like the fonts/colours.
    public var titleOffsetX: Double
    public var titleOffsetY: Double
    public var artistOffsetX: Double
    public var artistOffsetY: Double
    public var genreOffsetX: Double
    public var genreOffsetY: Double
    public var yearOffsetX: Double
    public var yearOffsetY: Double
    public var singerOffsetX: Double
    public var singerOffsetY: Double
    public var trackCounterOffsetX: Double
    public var trackCounterOffsetY: Double
    public var lastTandaLabelOffsetX: Double
    public var lastTandaLabelOffsetY: Double
    public var cortinaLabelOffsetX: Double
    public var cortinaLabelOffsetY: Double
    public var cortinaArtistOffsetX: Double
    public var cortinaArtistOffsetY: Double
    public var cortinaTitleOffsetX: Double
    public var cortinaTitleOffsetY: Double
    public var nextUpLabelOffsetX: Double
    public var nextUpLabelOffsetY: Double
    public var lastPlayedOffsetX: Double
    public var lastPlayedOffsetY: Double

    // Per-element text-box width (points) for single-line auto-shrink when a horizontal offset is set.
    // 0 = disabled (text uses the full width as before). See ColorExtension.positioned.
    public var titleBoxWidth: Double
    public var artistBoxWidth: Double
    public var genreBoxWidth: Double
    public var yearBoxWidth: Double
    public var singerBoxWidth: Double
    public var trackCounterBoxWidth: Double
    public var lastTandaLabelBoxWidth: Double
    public var cortinaLabelBoxWidth: Double
    public var cortinaArtistBoxWidth: Double
    public var cortinaTitleBoxWidth: Double
    public var nextUpLabelBoxWidth: Double
    public var lastPlayedBoxWidth: Double

    // Horizontal alignment of each element within its box (or the full width when no box is set).
    public var titleHAlign: TextHAlignment
    public var artistHAlign: TextHAlignment
    public var genreHAlign: TextHAlignment
    public var yearHAlign: TextHAlignment
    public var singerHAlign: TextHAlignment
    public var trackCounterHAlign: TextHAlignment
    public var lastTandaLabelHAlign: TextHAlignment
    public var cortinaLabelHAlign: TextHAlignment
    public var cortinaArtistHAlign: TextHAlignment
    public var cortinaTitleHAlign: TextHAlignment
    public var nextUpLabelHAlign: TextHAlignment
    public var lastPlayedHAlign: TextHAlignment

    // When true, the *Offset and *BoxWidth values above are percentages (0–100) of the presentation
    // resolution (X/box → % of width, Y → % of height) instead of absolute points. Older profiles
    // (flag absent) are migrated from points to percent on decode against a 1920×1080 baseline.
    public var relativePositions: Bool
    /// When true, the *FontSize values are levels (1–15 = percent of the presentation height) rather
    /// than absolute points. Older profiles (flag absent) are migrated from points on decode.
    public var relativeFontSizes: Bool
    /// When true, albumArtworkOffsetX/Y are percentages of the resolution (X = % width, Y = % height)
    /// rather than absolute points. Older profiles (flag absent) are migrated from points on decode.
    public var relativeArtworkPosition: Bool

    // TDJ name (the DJ's name on the dancer display; the name text, global toggle,
    // corner/centre position and show-when rule live in AppSettings — the profile only
    // styles and places the centre-mode element).
    public var tdjNameColor: String = "#AAAAAA"
    public var tdjNameFontName: String = "System"
    public var tdjNameFontSize: Double = 3
    public var tdjNameFontBold: Bool = false
    public var tdjNameFontItalic: Bool = false
    public var tdjNameOffsetX: Double = 0
    public var tdjNameOffsetY: Double = 0
    public var tdjNameBoxWidth: Double = 0
    public var tdjNameHAlign: TextHAlignment = .center

    /// How the presentation lays out text elements (see `LayoutMode`). In `.absolute`
    /// the *Offset percentages anchor each element from screen centre, so an empty
    /// field never shifts its neighbours. Older profiles (key absent) stay `.flow`.
    public var layoutMode: LayoutMode = .flow

    public init(id: UUID, name: String, isBuiltIn: Bool,
                titleFontName: String = "System", titleFontSize: Double = 7,
                titleFontBold: Bool = true, titleFontItalic: Bool = false,
                artistFontName: String = "System", artistFontSize: Double = 9,
                artistFontBold: Bool = false, artistFontItalic: Bool = false,
                genreFontName: String = "System", genreFontSize: Double = 3,
                genreFontBold: Bool = false, genreFontItalic: Bool = false,
                showYear: Bool = false,
                yearFontName: String = "System", yearFontSize: Double = 3,
                yearFontBold: Bool = false, yearFontItalic: Bool = false,
                backgroundColor: String = "#000000",
                titleColor: String = "#FFFFFF",
                artistColor: String = "#FFFFFF",
                genreColor: String = "#AAAAAA",
                yearColor: String = "#AAAAAA",
                trackCounterColor: String = "#AAAAAA",
                transitionStyle: TransitionStyle = .fade,
                transitionDuration: Double = 0.4,
                backgroundImageFilename: String? = nil,
                backgroundImageOpacity: Double = 1.0,
                backgroundImageScale: Double = 1.0,
                backgroundImageOffsetX: Double = 0.0,
                backgroundImageOffsetY: Double = 0.0,
                artistBackgroundsEnabled: Bool = false,
                artistBackgrounds: [ArtistBackground] = [],
                artistBackgroundOpacity: Double = 1.0,
                artistBackgroundScale: Double = 1.0,
                artistBackgroundOffsetX: Double = 0.0,
                artistBackgroundOffsetY: Double = 0.0,
                genreBackgroundsEnabled: Bool = false,
                genreBackgrounds: [GenreBackground] = [],
                genreBackgroundOpacity: Double = 1.0,
                genreBackgroundScale: Double = 1.0,
                genreBackgroundOffsetX: Double = 0.0,
                genreBackgroundOffsetY: Double = 0.0,
                showAlbumArtwork: Bool = false,
                albumArtworkOpacity: Double = 1.0,
                albumArtworkScale: Double = 1.0,
                albumArtworkOffsetX: Double = 0.0,
                albumArtworkOffsetY: Double = 0.0,
                albumArtworkEdgeFade: Double = 0.0,
                albumArtworkFadeStyle: AlbumArtFadeStyle = .radial,
                albumArtworkBackingEnabled: Bool = false,
                albumArtworkBackingColor: String = "#000000",
                albumArtworkBackingScale: Double = 1.0,
                albumArtworkBackingOpacity: Double = 1.0,
                albumArtworkBackingEdgeFade: Double = 0.0,
                albumArtworkBackingFadeStyle: AlbumArtFadeStyle = .radial,
                genreTextCase: GenreTextCase = .uppercase,
                yearInParentheses: Bool = false,
                lastPlayedFontName: String = "System", lastPlayedFontSize: Double = 3,
                lastPlayedFontBold: Bool = false, lastPlayedFontItalic: Bool = false,
                lastPlayedColor: String = "#AAAAAA",
                showLastPlayedDance: Bool = false, showLastPlayedCortina: Bool = false,
                danceItemOrder: [DisplayTextItem] = [.genre, .artist, .year, .title, .singer, .lastTandaLabel, .tdjName, .trackCounter, .lastPlayed],
                cortinaItemOrder: [DisplayTextItem] = [.genre, .artist, .year, .singer, .lastTandaLabel, .tdjName, .lastPlayed],
                showSinger: Bool = false,
                singerSource: SingerSource = .comments,
                showSingerDuringCortina: Bool = false,
                singerFontName: String = "System",
                singerFontSize: Double = 4,
                singerFontBold: Bool = false,
                singerFontItalic: Bool = false,
                singerColor: String = "#AAAAAA",
                showGenreDance: Bool = true,
                showArtistDance: Bool = true,
                showYearDance: Bool = false,
                showTitleDance: Bool = true,
                showSingerDance: Bool = false,
                showArtworkDance: Bool = false,
                showNextTrackDuringCortina: Bool = true,
                showGenreCortina: Bool = true,
                showArtistCortina: Bool = true,
                showYearCortina: Bool = false,
                showTitleCortina: Bool = false,
                showSingerCortina: Bool = false,
                showArtworkCortina: Bool = false,
                showCortinaTrackDuringCortina: Bool = false,
                showCortinaTrackArtist: Bool = true,
                showCortinaTrackTitle: Bool = true,
                showCortinaTrackYear: Bool = false,
                showCortinaLabel: Bool = true,
                cortinaLabelFontName: String = "System", cortinaLabelFontSize: Double = 7,
                cortinaLabelFontBold: Bool = false, cortinaLabelFontItalic: Bool = false,
                cortinaLabelColor: String = "#FFFFFF",
                cortinaArtistFontName: String = "System", cortinaArtistFontSize: Double = 9,
                cortinaArtistFontBold: Bool = false, cortinaArtistFontItalic: Bool = false,
                cortinaArtistColor: String = "#FFFFFF",
                cortinaTitleFontName: String = "System", cortinaTitleFontSize: Double = 7,
                cortinaTitleFontBold: Bool = false, cortinaTitleFontItalic: Bool = false,
                cortinaTitleColor: String = "#FFFFFF",
                nextUpLabelFontName: String = "System", nextUpLabelFontSize: Double = 3,
                nextUpLabelFontBold: Bool = false, nextUpLabelFontItalic: Bool = false,
                nextUpLabelColor: String = "#AAAAAA",
                idleMessageFontName: String = "System", idleMessageFontSize: Double = 4,
                idleMessageFontBold: Bool = false, idleMessageFontItalic: Bool = false,
                idleMessageColor: String = "#FFFFFF",
                cortinaTrackItemOrder: [DisplayTextItem] = [.cortinaLabel, .cortinaArtist, .cortinaTitle],
                lastTandaLabelFontName: String = "System", lastTandaLabelFontSize: Double = 3,
                lastTandaLabelFontBold: Bool = false, lastTandaLabelFontItalic: Bool = false,
                lastTandaLabelColor: String = "#FF4444",
                showLastTandaLabel: Bool = true,
                trackCounterFontName: String = "System", trackCounterFontSize: Double = 3,
                trackCounterFontBold: Bool = false, trackCounterFontItalic: Bool = false,
                overrideTextFontName: String = "System", overrideTextFontSize: Double = 7,
                overrideTextFontBold: Bool = false, overrideTextFontItalic: Bool = false,
                overrideTextColor: String = "#FFFFFF",
                titleOffsetX: Double = 0, titleOffsetY: Double = 0,
                artistOffsetX: Double = 0, artistOffsetY: Double = 0,
                genreOffsetX: Double = 0, genreOffsetY: Double = 0,
                yearOffsetX: Double = 0, yearOffsetY: Double = 0,
                singerOffsetX: Double = 0, singerOffsetY: Double = 0,
                trackCounterOffsetX: Double = 0, trackCounterOffsetY: Double = 0,
                lastTandaLabelOffsetX: Double = 0, lastTandaLabelOffsetY: Double = 0,
                cortinaLabelOffsetX: Double = 0, cortinaLabelOffsetY: Double = 0,
                cortinaArtistOffsetX: Double = 0, cortinaArtistOffsetY: Double = 0,
                cortinaTitleOffsetX: Double = 0, cortinaTitleOffsetY: Double = 0,
                nextUpLabelOffsetX: Double = 0, nextUpLabelOffsetY: Double = 0,
                lastPlayedOffsetX: Double = 0, lastPlayedOffsetY: Double = 0,
                titleBoxWidth: Double = 0, artistBoxWidth: Double = 0,
                genreBoxWidth: Double = 0, yearBoxWidth: Double = 0,
                singerBoxWidth: Double = 0, trackCounterBoxWidth: Double = 0,
                lastTandaLabelBoxWidth: Double = 0, cortinaLabelBoxWidth: Double = 0,
                cortinaArtistBoxWidth: Double = 0, cortinaTitleBoxWidth: Double = 0,
                nextUpLabelBoxWidth: Double = 0,
                lastPlayedBoxWidth: Double = 0,
                titleHAlign: TextHAlignment = .center, artistHAlign: TextHAlignment = .center,
                genreHAlign: TextHAlignment = .center, yearHAlign: TextHAlignment = .center,
                singerHAlign: TextHAlignment = .center, trackCounterHAlign: TextHAlignment = .center,
                lastTandaLabelHAlign: TextHAlignment = .center, cortinaLabelHAlign: TextHAlignment = .center,
                cortinaArtistHAlign: TextHAlignment = .center, cortinaTitleHAlign: TextHAlignment = .center,
                nextUpLabelHAlign: TextHAlignment = .center,
                lastPlayedHAlign: TextHAlignment = .center,
                relativePositions: Bool = true,
                relativeFontSizes: Bool = true,
                relativeArtworkPosition: Bool = true) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.titleFontName = titleFontName
        self.titleFontSize = titleFontSize
        self.titleFontBold = titleFontBold
        self.titleFontItalic = titleFontItalic
        self.artistFontName = artistFontName
        self.artistFontSize = artistFontSize
        self.artistFontBold = artistFontBold
        self.artistFontItalic = artistFontItalic
        self.genreFontName = genreFontName
        self.genreFontSize = genreFontSize
        self.genreFontBold = genreFontBold
        self.genreFontItalic = genreFontItalic
        self.showYear = showYear
        self.yearFontName = yearFontName
        self.yearFontSize = yearFontSize
        self.yearFontBold = yearFontBold
        self.yearFontItalic = yearFontItalic
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.artistColor = artistColor
        self.genreColor = genreColor
        self.yearColor = yearColor
        self.trackCounterColor = trackCounterColor
        self.transitionStyle = transitionStyle
        self.transitionDuration = transitionDuration
        self.backgroundImageFilename = backgroundImageFilename
        self.backgroundImageOpacity = backgroundImageOpacity
        self.backgroundImageScale = backgroundImageScale
        self.backgroundImageOffsetX = backgroundImageOffsetX
        self.backgroundImageOffsetY = backgroundImageOffsetY
        self.artistBackgroundsEnabled = artistBackgroundsEnabled
        self.artistBackgrounds        = artistBackgrounds
        self.artistBackgroundOpacity  = artistBackgroundOpacity
        self.artistBackgroundScale    = artistBackgroundScale
        self.artistBackgroundOffsetX  = artistBackgroundOffsetX
        self.artistBackgroundOffsetY  = artistBackgroundOffsetY
        self.genreBackgroundsEnabled = genreBackgroundsEnabled
        self.genreBackgrounds        = genreBackgrounds
        self.genreBackgroundOpacity  = genreBackgroundOpacity
        self.genreBackgroundScale    = genreBackgroundScale
        self.genreBackgroundOffsetX  = genreBackgroundOffsetX
        self.genreBackgroundOffsetY  = genreBackgroundOffsetY
        self.showAlbumArtwork = showAlbumArtwork
        self.albumArtworkOpacity = albumArtworkOpacity
        self.albumArtworkScale = albumArtworkScale
        self.albumArtworkOffsetX = albumArtworkOffsetX
        self.albumArtworkOffsetY = albumArtworkOffsetY
        self.albumArtworkEdgeFade = albumArtworkEdgeFade
        self.albumArtworkFadeStyle = albumArtworkFadeStyle
        self.albumArtworkBackingEnabled = albumArtworkBackingEnabled
        self.albumArtworkBackingColor = albumArtworkBackingColor
        self.albumArtworkBackingScale = albumArtworkBackingScale
        self.albumArtworkBackingOpacity = albumArtworkBackingOpacity
        self.albumArtworkBackingEdgeFade = albumArtworkBackingEdgeFade
        self.albumArtworkBackingFadeStyle = albumArtworkBackingFadeStyle
        self.genreTextCase = genreTextCase
        self.yearInParentheses = yearInParentheses
        self.danceItemOrder = danceItemOrder
        self.cortinaItemOrder = cortinaItemOrder
        self.showSinger = showSinger
        self.singerSource = singerSource
        self.showSingerDuringCortina = showSingerDuringCortina
        self.singerFontName = singerFontName
        self.singerFontSize = singerFontSize
        self.singerFontBold = singerFontBold
        self.singerFontItalic = singerFontItalic
        self.singerColor = singerColor
        self.showGenreDance   = showGenreDance
        self.showArtistDance  = showArtistDance
        self.showYearDance    = showYearDance
        self.showTitleDance   = showTitleDance
        self.showSingerDance  = showSingerDance
        self.showArtworkDance = showArtworkDance
        self.showNextTrackDuringCortina = showNextTrackDuringCortina
        self.showGenreCortina   = showGenreCortina
        self.showArtistCortina  = showArtistCortina
        self.showYearCortina    = showYearCortina
        self.showTitleCortina   = showTitleCortina
        self.showSingerCortina  = showSingerCortina
        self.showArtworkCortina = showArtworkCortina
        self.showCortinaTrackDuringCortina = showCortinaTrackDuringCortina
        self.showCortinaTrackArtist = showCortinaTrackArtist
        self.showCortinaTrackTitle  = showCortinaTrackTitle
        self.showCortinaTrackYear   = showCortinaTrackYear
        self.showCortinaLabel       = showCortinaLabel
        self.cortinaLabelFontName   = cortinaLabelFontName
        self.cortinaLabelFontSize   = cortinaLabelFontSize
        self.cortinaLabelFontBold   = cortinaLabelFontBold
        self.cortinaLabelFontItalic = cortinaLabelFontItalic
        self.cortinaLabelColor      = cortinaLabelColor
        self.cortinaArtistFontName   = cortinaArtistFontName
        self.cortinaArtistFontSize   = cortinaArtistFontSize
        self.cortinaArtistFontBold   = cortinaArtistFontBold
        self.cortinaArtistFontItalic = cortinaArtistFontItalic
        self.cortinaArtistColor      = cortinaArtistColor
        self.cortinaTitleFontName   = cortinaTitleFontName
        self.cortinaTitleFontSize   = cortinaTitleFontSize
        self.cortinaTitleFontBold   = cortinaTitleFontBold
        self.cortinaTitleFontItalic = cortinaTitleFontItalic
        self.cortinaTitleColor      = cortinaTitleColor
        self.nextUpLabelFontName   = nextUpLabelFontName
        self.nextUpLabelFontSize   = nextUpLabelFontSize
        self.nextUpLabelFontBold   = nextUpLabelFontBold
        self.nextUpLabelFontItalic = nextUpLabelFontItalic
        self.nextUpLabelColor      = nextUpLabelColor
        self.idleMessageFontName   = idleMessageFontName
        self.idleMessageFontSize   = idleMessageFontSize
        self.idleMessageFontBold   = idleMessageFontBold
        self.idleMessageFontItalic = idleMessageFontItalic
        self.idleMessageColor      = idleMessageColor
        self.cortinaTrackItemOrder = cortinaTrackItemOrder
        self.lastTandaLabelFontName   = lastTandaLabelFontName
        self.lastTandaLabelFontSize   = lastTandaLabelFontSize
        self.lastTandaLabelFontBold   = lastTandaLabelFontBold
        self.lastTandaLabelFontItalic = lastTandaLabelFontItalic
        self.lastTandaLabelColor      = lastTandaLabelColor
        self.showLastTandaLabel       = showLastTandaLabel
        self.lastPlayedFontName   = lastPlayedFontName
        self.lastPlayedFontSize   = lastPlayedFontSize
        self.lastPlayedFontBold   = lastPlayedFontBold
        self.lastPlayedFontItalic = lastPlayedFontItalic
        self.lastPlayedColor      = lastPlayedColor
        self.showLastPlayedDance   = showLastPlayedDance
        self.showLastPlayedCortina = showLastPlayedCortina
        self.trackCounterFontName     = trackCounterFontName
        self.trackCounterFontSize     = trackCounterFontSize
        self.trackCounterFontBold     = trackCounterFontBold
        self.trackCounterFontItalic   = trackCounterFontItalic
        self.overrideTextFontName   = overrideTextFontName
        self.overrideTextFontSize   = overrideTextFontSize
        self.overrideTextFontBold   = overrideTextFontBold
        self.overrideTextFontItalic = overrideTextFontItalic
        self.overrideTextColor      = overrideTextColor
        self.titleOffsetX = titleOffsetX;             self.titleOffsetY = titleOffsetY
        self.artistOffsetX = artistOffsetX;           self.artistOffsetY = artistOffsetY
        self.genreOffsetX = genreOffsetX;             self.genreOffsetY = genreOffsetY
        self.yearOffsetX = yearOffsetX;               self.yearOffsetY = yearOffsetY
        self.singerOffsetX = singerOffsetX;           self.singerOffsetY = singerOffsetY
        self.trackCounterOffsetX = trackCounterOffsetX; self.trackCounterOffsetY = trackCounterOffsetY
        self.lastTandaLabelOffsetX = lastTandaLabelOffsetX; self.lastTandaLabelOffsetY = lastTandaLabelOffsetY
        self.cortinaLabelOffsetX = cortinaLabelOffsetX; self.cortinaLabelOffsetY = cortinaLabelOffsetY
        self.cortinaArtistOffsetX = cortinaArtistOffsetX; self.cortinaArtistOffsetY = cortinaArtistOffsetY
        self.cortinaTitleOffsetX = cortinaTitleOffsetX; self.cortinaTitleOffsetY = cortinaTitleOffsetY
        self.nextUpLabelOffsetX = nextUpLabelOffsetX;  self.nextUpLabelOffsetY = nextUpLabelOffsetY
        self.lastPlayedOffsetX = lastPlayedOffsetX;    self.lastPlayedOffsetY = lastPlayedOffsetY
        self.titleBoxWidth = titleBoxWidth;           self.artistBoxWidth = artistBoxWidth
        self.genreBoxWidth = genreBoxWidth;           self.yearBoxWidth = yearBoxWidth
        self.singerBoxWidth = singerBoxWidth;         self.trackCounterBoxWidth = trackCounterBoxWidth
        self.lastTandaLabelBoxWidth = lastTandaLabelBoxWidth; self.cortinaLabelBoxWidth = cortinaLabelBoxWidth
        self.cortinaArtistBoxWidth = cortinaArtistBoxWidth;   self.cortinaTitleBoxWidth = cortinaTitleBoxWidth
        self.nextUpLabelBoxWidth = nextUpLabelBoxWidth
        self.lastPlayedBoxWidth = lastPlayedBoxWidth
        self.titleHAlign = titleHAlign;             self.artistHAlign = artistHAlign
        self.genreHAlign = genreHAlign;             self.yearHAlign = yearHAlign
        self.singerHAlign = singerHAlign;           self.trackCounterHAlign = trackCounterHAlign
        self.lastTandaLabelHAlign = lastTandaLabelHAlign; self.cortinaLabelHAlign = cortinaLabelHAlign
        self.cortinaArtistHAlign = cortinaArtistHAlign;   self.cortinaTitleHAlign = cortinaTitleHAlign
        self.nextUpLabelHAlign = nextUpLabelHAlign
        self.lastPlayedHAlign = lastPlayedHAlign
        self.relativePositions = relativePositions
        self.relativeFontSizes = relativeFontSizes
        self.relativeArtworkPosition = relativeArtworkPosition
    }

    // Custom decoder so existing JSON lacking the image keys still loads cleanly.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self,            forKey: .id)
        name                 = try c.decode(String.self,          forKey: .name)
        isBuiltIn            = try c.decode(Bool.self,            forKey: .isBuiltIn)
        titleFontName        = try c.decode(String.self,          forKey: .titleFontName)
        titleFontSize        = try c.decode(Double.self,          forKey: .titleFontSize)
        titleFontBold        = try c.decodeIfPresent(Bool.self,    forKey: .titleFontBold)    ?? false
        titleFontItalic      = try c.decodeIfPresent(Bool.self,    forKey: .titleFontItalic)   ?? false
        artistFontName       = try c.decode(String.self,           forKey: .artistFontName)
        artistFontSize       = try c.decode(Double.self,           forKey: .artistFontSize)
        artistFontBold       = try c.decodeIfPresent(Bool.self,    forKey: .artistFontBold)    ?? false
        artistFontItalic     = try c.decodeIfPresent(Bool.self,    forKey: .artistFontItalic)  ?? false
        genreFontName        = try c.decode(String.self,           forKey: .genreFontName)
        genreFontSize        = try c.decode(Double.self,           forKey: .genreFontSize)
        genreFontBold        = try c.decodeIfPresent(Bool.self,    forKey: .genreFontBold)     ?? false
        genreFontItalic      = try c.decodeIfPresent(Bool.self,    forKey: .genreFontItalic)   ?? false
        showYear             = try c.decodeIfPresent(Bool.self,    forKey: .showYear)          ?? false
        yearFontName         = try c.decodeIfPresent(String.self,  forKey: .yearFontName)      ?? "System"
        yearFontSize         = try c.decodeIfPresent(Double.self,  forKey: .yearFontSize)      ?? 36
        yearFontBold         = try c.decodeIfPresent(Bool.self,    forKey: .yearFontBold)      ?? false
        yearFontItalic       = try c.decodeIfPresent(Bool.self,    forKey: .yearFontItalic)    ?? false
        backgroundColor      = try c.decode(String.self,          forKey: .backgroundColor)
        titleColor           = try c.decode(String.self,          forKey: .titleColor)
        artistColor          = try c.decode(String.self,          forKey: .artistColor)
        genreColor           = try c.decode(String.self,          forKey: .genreColor)
        yearColor            = try c.decodeIfPresent(String.self,  forKey: .yearColor)         ?? "#AAAAAA"
        trackCounterColor    = try c.decodeIfPresent(String.self, forKey: .trackCounterColor) ?? "#AAAAAA"
        // Tolerant decode: an unknown raw value (file from a newer app version, or hand-edited)
        // must not fail the whole profile — fall back to the default style.
        if let rawTransition = try c.decodeIfPresent(String.self, forKey: .transitionStyle) {
            transitionStyle = TransitionStyle(rawValue: rawTransition) ?? .fade
        } else {
            transitionStyle = .fade
        }
        transitionDuration   = try c.decode(Double.self,          forKey: .transitionDuration)
        // New fields — absent in older JSON files, fall back to defaults
        backgroundImageFilename = try c.decodeIfPresent(String.self,  forKey: .backgroundImageFilename)
        backgroundImageOpacity  = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageOpacity)  ?? 1.0
        backgroundImageScale    = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageScale)    ?? 1.0
        backgroundImageOffsetX  = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageOffsetX)  ?? 0.0
        backgroundImageOffsetY  = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageOffsetY)  ?? 0.0
        artistBackgroundsEnabled = try c.decodeIfPresent(Bool.self,               forKey: .artistBackgroundsEnabled) ?? false
        artistBackgrounds        = try c.decodeIfPresent([ArtistBackground].self, forKey: .artistBackgrounds)        ?? []
        artistBackgroundOpacity  = try c.decodeIfPresent(Double.self,             forKey: .artistBackgroundOpacity)  ?? 1.0
        artistBackgroundScale    = try c.decodeIfPresent(Double.self,             forKey: .artistBackgroundScale)    ?? 1.0
        artistBackgroundOffsetX  = try c.decodeIfPresent(Double.self,             forKey: .artistBackgroundOffsetX)  ?? 0.0
        artistBackgroundOffsetY  = try c.decodeIfPresent(Double.self,             forKey: .artistBackgroundOffsetY)  ?? 0.0
        genreBackgroundsEnabled  = try c.decodeIfPresent(Bool.self,              forKey: .genreBackgroundsEnabled)  ?? false
        genreBackgrounds         = try c.decodeIfPresent([GenreBackground].self, forKey: .genreBackgrounds)         ?? []
        genreBackgroundOpacity   = try c.decodeIfPresent(Double.self,            forKey: .genreBackgroundOpacity)   ?? 1.0
        genreBackgroundScale     = try c.decodeIfPresent(Double.self,            forKey: .genreBackgroundScale)     ?? 1.0
        genreBackgroundOffsetX   = try c.decodeIfPresent(Double.self,            forKey: .genreBackgroundOffsetX)   ?? 0.0
        genreBackgroundOffsetY   = try c.decodeIfPresent(Double.self,            forKey: .genreBackgroundOffsetY)   ?? 0.0
        showAlbumArtwork        = try c.decodeIfPresent(Bool.self,    forKey: .showAlbumArtwork)        ?? false
        albumArtworkOpacity     = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkOpacity)     ?? 1.0
        albumArtworkScale       = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkScale)       ?? 1.0
        albumArtworkOffsetX     = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkOffsetX)     ?? 0.0
        albumArtworkOffsetY     = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkOffsetY)     ?? 0.0
        albumArtworkEdgeFade    = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkEdgeFade)    ?? 0.0
        albumArtworkFadeStyle   = try c.decodeIfPresent(AlbumArtFadeStyle.self, forKey: .albumArtworkFadeStyle) ?? .radial
        albumArtworkBackingEnabled  = try c.decodeIfPresent(Bool.self,   forKey: .albumArtworkBackingEnabled)  ?? false
        albumArtworkBackingColor    = try c.decodeIfPresent(String.self, forKey: .albumArtworkBackingColor)    ?? "#000000"
        albumArtworkBackingScale    = try c.decodeIfPresent(Double.self, forKey: .albumArtworkBackingScale)    ?? 1.0
        albumArtworkBackingOpacity  = try c.decodeIfPresent(Double.self, forKey: .albumArtworkBackingOpacity)  ?? 1.0
        albumArtworkBackingEdgeFade = try c.decodeIfPresent(Double.self, forKey: .albumArtworkBackingEdgeFade) ?? 0.0
        albumArtworkBackingFadeStyle = try c.decodeIfPresent(AlbumArtFadeStyle.self, forKey: .albumArtworkBackingFadeStyle) ?? .radial
        genreTextCase           = try c.decodeIfPresent(GenreTextCase.self,     forKey: .genreTextCase)           ?? .uppercase
        yearInParentheses       = try c.decodeIfPresent(Bool.self,              forKey: .yearInParentheses)       ?? false
        showSinger              = try c.decodeIfPresent(Bool.self,         forKey: .showSinger)              ?? false
        // Tolerant decode: an older profile may carry a removed raw value (e.g. "artist") — map it to the
        // default rather than failing the whole profile decode.
        if let rawSinger = try c.decodeIfPresent(String.self, forKey: .singerSource) {
            singerSource = SingerSource(rawValue: rawSinger) ?? .comments
        } else {
            singerSource = .comments
        }
        showSingerDuringCortina = try c.decodeIfPresent(Bool.self,         forKey: .showSingerDuringCortina) ?? false
        singerFontName          = try c.decodeIfPresent(String.self,  forKey: .singerFontName)          ?? "System"
        singerFontSize          = try c.decodeIfPresent(Double.self,  forKey: .singerFontSize)          ?? 48
        singerFontBold          = try c.decodeIfPresent(Bool.self,    forKey: .singerFontBold)          ?? false
        singerFontItalic        = try c.decodeIfPresent(Bool.self,    forKey: .singerFontItalic)        ?? false
        singerColor             = try c.decodeIfPresent(String.self,  forKey: .singerColor)             ?? "#AAAAAA"
        danceItemOrder   = try c.decodeIfPresent([DisplayTextItem].self, forKey: .danceItemOrder)   ?? [.genre, .artist, .year, .title, .singer]
        var decodedCortinaOrder = try c.decodeIfPresent([DisplayTextItem].self, forKey: .cortinaItemOrder) ?? [.genre, .artist, .year, .singer]
        if !decodedCortinaOrder.contains(.title) {
            if let singerIdx = decodedCortinaOrder.firstIndex(of: .singer) {
                decodedCortinaOrder.insert(.title, at: singerIdx)
            } else {
                decodedCortinaOrder.append(.title)
            }
        }
        if !decodedCortinaOrder.contains(.nextUpLabel) {
            decodedCortinaOrder.insert(.nextUpLabel, at: 0)
        }
        cortinaItemOrder = decodedCortinaOrder

        // Legacy field values for migration
        let legacyShowYear          = (try c.decodeIfPresent(Bool.self, forKey: .showYear))             ?? false
        let legacyShowSinger        = (try c.decodeIfPresent(Bool.self, forKey: .showSinger))           ?? false
        let legacyShowSingerCortina = (try c.decodeIfPresent(Bool.self, forKey: .showSingerDuringCortina)) ?? false
        let legacyShowArtwork       = (try c.decodeIfPresent(Bool.self, forKey: .showAlbumArtwork))     ?? false
        let legacyCortinaHadTitle   = (try c.decodeIfPresent([DisplayTextItem].self, forKey: .cortinaItemOrder))?.contains(.title) ?? false

        showGenreDance   = (try c.decodeIfPresent(Bool.self, forKey: .showGenreDance))   ?? true
        showArtistDance  = (try c.decodeIfPresent(Bool.self, forKey: .showArtistDance))  ?? true
        showYearDance    = (try c.decodeIfPresent(Bool.self, forKey: .showYearDance))    ?? legacyShowYear
        showTitleDance   = (try c.decodeIfPresent(Bool.self, forKey: .showTitleDance))   ?? true
        showSingerDance  = (try c.decodeIfPresent(Bool.self, forKey: .showSingerDance))  ?? legacyShowSinger
        showArtworkDance = (try c.decodeIfPresent(Bool.self, forKey: .showArtworkDance)) ?? legacyShowArtwork

        showNextTrackDuringCortina = (try c.decodeIfPresent(Bool.self, forKey: .showNextTrackDuringCortina)) ?? true
        showGenreCortina   = (try c.decodeIfPresent(Bool.self, forKey: .showGenreCortina))   ?? true
        showArtistCortina  = (try c.decodeIfPresent(Bool.self, forKey: .showArtistCortina))  ?? true
        showYearCortina    = (try c.decodeIfPresent(Bool.self, forKey: .showYearCortina))    ?? legacyShowYear
        showTitleCortina   = (try c.decodeIfPresent(Bool.self, forKey: .showTitleCortina))   ?? legacyCortinaHadTitle
        showSingerCortina  = (try c.decodeIfPresent(Bool.self, forKey: .showSingerCortina))  ?? legacyShowSingerCortina
        showArtworkCortina = (try c.decodeIfPresent(Bool.self, forKey: .showArtworkCortina)) ?? legacyShowArtwork

        showCortinaTrackDuringCortina = (try c.decodeIfPresent(Bool.self, forKey: .showCortinaTrackDuringCortina)) ?? false
        showCortinaTrackArtist        = (try c.decodeIfPresent(Bool.self, forKey: .showCortinaTrackArtist))        ?? true
        showCortinaTrackTitle         = (try c.decodeIfPresent(Bool.self, forKey: .showCortinaTrackTitle))         ?? true
        showCortinaTrackYear          = (try c.decodeIfPresent(Bool.self, forKey: .showCortinaTrackYear))          ?? false
        showCortinaLabel              = (try c.decodeIfPresent(Bool.self, forKey: .showCortinaLabel))              ?? true

        cortinaLabelFontName   = try c.decodeIfPresent(String.self, forKey: .cortinaLabelFontName)   ?? titleFontName
        cortinaLabelFontSize   = try c.decodeIfPresent(Double.self, forKey: .cortinaLabelFontSize)   ?? titleFontSize
        cortinaLabelFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .cortinaLabelFontBold)   ?? titleFontBold
        cortinaLabelFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .cortinaLabelFontItalic) ?? titleFontItalic
        cortinaLabelColor      = try c.decodeIfPresent(String.self, forKey: .cortinaLabelColor)      ?? artistColor

        cortinaArtistFontName   = try c.decodeIfPresent(String.self, forKey: .cortinaArtistFontName)   ?? "System"
        cortinaArtistFontSize   = try c.decodeIfPresent(Double.self, forKey: .cortinaArtistFontSize)   ?? 96
        cortinaArtistFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .cortinaArtistFontBold)   ?? false
        cortinaArtistFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .cortinaArtistFontItalic) ?? false
        cortinaArtistColor      = try c.decodeIfPresent(String.self, forKey: .cortinaArtistColor)      ?? "#FFFFFF"

        cortinaTitleFontName   = try c.decodeIfPresent(String.self, forKey: .cortinaTitleFontName)   ?? "System"
        cortinaTitleFontSize   = try c.decodeIfPresent(Double.self, forKey: .cortinaTitleFontSize)   ?? 72
        cortinaTitleFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .cortinaTitleFontBold)   ?? false
        cortinaTitleFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .cortinaTitleFontItalic) ?? false
        cortinaTitleColor      = try c.decodeIfPresent(String.self, forKey: .cortinaTitleColor)      ?? "#FFFFFF"

        nextUpLabelFontName   = try c.decodeIfPresent(String.self, forKey: .nextUpLabelFontName)   ?? genreFontName
        nextUpLabelFontSize   = try c.decodeIfPresent(Double.self, forKey: .nextUpLabelFontSize)   ?? genreFontSize
        nextUpLabelFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .nextUpLabelFontBold)   ?? genreFontBold
        nextUpLabelFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .nextUpLabelFontItalic) ?? genreFontItalic
        nextUpLabelColor      = try c.decodeIfPresent(String.self, forKey: .nextUpLabelColor)      ?? genreColor

        idleMessageFontName   = try c.decodeIfPresent(String.self, forKey: .idleMessageFontName)   ?? "System"
        idleMessageFontSize   = try c.decodeIfPresent(Double.self, forKey: .idleMessageFontSize)   ?? 48
        idleMessageFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .idleMessageFontBold)   ?? false
        idleMessageFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .idleMessageFontItalic) ?? false
        idleMessageColor      = try c.decodeIfPresent(String.self, forKey: .idleMessageColor)      ?? artistColor

        cortinaTrackItemOrder = try c.decodeIfPresent([DisplayTextItem].self, forKey: .cortinaTrackItemOrder)
            ?? [.cortinaLabel, .cortinaArtist, .cortinaTitle]

        lastTandaLabelFontName   = try c.decodeIfPresent(String.self, forKey: .lastTandaLabelFontName)   ?? "System"
        lastTandaLabelFontSize   = try c.decodeIfPresent(Double.self, forKey: .lastTandaLabelFontSize)   ?? 36
        lastTandaLabelFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .lastTandaLabelFontBold)   ?? false
        lastTandaLabelFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .lastTandaLabelFontItalic) ?? false
        lastTandaLabelColor      = try c.decodeIfPresent(String.self, forKey: .lastTandaLabelColor)      ?? "#FF4444"
        showLastTandaLabel       = try c.decodeIfPresent(Bool.self,   forKey: .showLastTandaLabel)       ?? true
        lastPlayedFontName    = try c.decodeIfPresent(String.self, forKey: .lastPlayedFontName)    ?? "System"
        lastPlayedFontSize    = try c.decodeIfPresent(Double.self, forKey: .lastPlayedFontSize)    ?? 36
        lastPlayedFontBold    = try c.decodeIfPresent(Bool.self,   forKey: .lastPlayedFontBold)    ?? false
        lastPlayedFontItalic  = try c.decodeIfPresent(Bool.self,   forKey: .lastPlayedFontItalic)  ?? false
        lastPlayedColor       = try c.decodeIfPresent(String.self, forKey: .lastPlayedColor)       ?? "#AAAAAA"
        showLastPlayedDance   = try c.decodeIfPresent(Bool.self,   forKey: .showLastPlayedDance)   ?? false
        showLastPlayedCortina = try c.decodeIfPresent(Bool.self,   forKey: .showLastPlayedCortina) ?? false

        trackCounterFontName   = try c.decodeIfPresent(String.self, forKey: .trackCounterFontName)   ?? "System"
        trackCounterFontSize   = try c.decodeIfPresent(Double.self, forKey: .trackCounterFontSize)   ?? 36
        trackCounterFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .trackCounterFontBold)   ?? false
        trackCounterFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .trackCounterFontItalic) ?? false

        overrideTextFontName   = try c.decodeIfPresent(String.self, forKey: .overrideTextFontName)   ?? "System"
        overrideTextFontSize   = try c.decodeIfPresent(Double.self, forKey: .overrideTextFontSize)   ?? 72
        overrideTextFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .overrideTextFontBold)   ?? false
        overrideTextFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .overrideTextFontItalic) ?? false
        overrideTextColor      = try c.decodeIfPresent(String.self, forKey: .overrideTextColor)      ?? titleColor

        // Per-element position offsets — absent in older JSON, default to 0 (centred, no offset).
        titleOffsetX          = try c.decodeIfPresent(Double.self, forKey: .titleOffsetX)          ?? 0
        titleOffsetY          = try c.decodeIfPresent(Double.self, forKey: .titleOffsetY)          ?? 0
        artistOffsetX         = try c.decodeIfPresent(Double.self, forKey: .artistOffsetX)         ?? 0
        artistOffsetY         = try c.decodeIfPresent(Double.self, forKey: .artistOffsetY)         ?? 0
        genreOffsetX          = try c.decodeIfPresent(Double.self, forKey: .genreOffsetX)          ?? 0
        genreOffsetY          = try c.decodeIfPresent(Double.self, forKey: .genreOffsetY)          ?? 0
        yearOffsetX           = try c.decodeIfPresent(Double.self, forKey: .yearOffsetX)           ?? 0
        yearOffsetY           = try c.decodeIfPresent(Double.self, forKey: .yearOffsetY)           ?? 0
        singerOffsetX         = try c.decodeIfPresent(Double.self, forKey: .singerOffsetX)         ?? 0
        singerOffsetY         = try c.decodeIfPresent(Double.self, forKey: .singerOffsetY)         ?? 0
        trackCounterOffsetX   = try c.decodeIfPresent(Double.self, forKey: .trackCounterOffsetX)   ?? 0
        trackCounterOffsetY   = try c.decodeIfPresent(Double.self, forKey: .trackCounterOffsetY)   ?? 0
        lastTandaLabelOffsetX = try c.decodeIfPresent(Double.self, forKey: .lastTandaLabelOffsetX) ?? 0
        lastTandaLabelOffsetY = try c.decodeIfPresent(Double.self, forKey: .lastTandaLabelOffsetY) ?? 0
        cortinaLabelOffsetX   = try c.decodeIfPresent(Double.self, forKey: .cortinaLabelOffsetX)   ?? 0
        cortinaLabelOffsetY   = try c.decodeIfPresent(Double.self, forKey: .cortinaLabelOffsetY)   ?? 0
        cortinaArtistOffsetX  = try c.decodeIfPresent(Double.self, forKey: .cortinaArtistOffsetX)  ?? 0
        cortinaArtistOffsetY  = try c.decodeIfPresent(Double.self, forKey: .cortinaArtistOffsetY)  ?? 0
        cortinaTitleOffsetX   = try c.decodeIfPresent(Double.self, forKey: .cortinaTitleOffsetX)   ?? 0
        cortinaTitleOffsetY   = try c.decodeIfPresent(Double.self, forKey: .cortinaTitleOffsetY)   ?? 0
        nextUpLabelOffsetX    = try c.decodeIfPresent(Double.self, forKey: .nextUpLabelOffsetX)    ?? 0
        nextUpLabelOffsetY    = try c.decodeIfPresent(Double.self, forKey: .nextUpLabelOffsetY)    ?? 0
        lastPlayedOffsetX     = try c.decodeIfPresent(Double.self, forKey: .lastPlayedOffsetX)     ?? 0
        lastPlayedOffsetY     = try c.decodeIfPresent(Double.self, forKey: .lastPlayedOffsetY)     ?? 0

        // Per-element text-box widths (auto-shrink) — absent in older JSON, default to 0 (disabled).
        titleBoxWidth          = try c.decodeIfPresent(Double.self, forKey: .titleBoxWidth)          ?? 0
        artistBoxWidth         = try c.decodeIfPresent(Double.self, forKey: .artistBoxWidth)         ?? 0
        genreBoxWidth          = try c.decodeIfPresent(Double.self, forKey: .genreBoxWidth)          ?? 0
        yearBoxWidth           = try c.decodeIfPresent(Double.self, forKey: .yearBoxWidth)           ?? 0
        singerBoxWidth         = try c.decodeIfPresent(Double.self, forKey: .singerBoxWidth)         ?? 0
        trackCounterBoxWidth   = try c.decodeIfPresent(Double.self, forKey: .trackCounterBoxWidth)   ?? 0
        lastTandaLabelBoxWidth = try c.decodeIfPresent(Double.self, forKey: .lastTandaLabelBoxWidth) ?? 0
        cortinaLabelBoxWidth   = try c.decodeIfPresent(Double.self, forKey: .cortinaLabelBoxWidth)   ?? 0
        cortinaArtistBoxWidth  = try c.decodeIfPresent(Double.self, forKey: .cortinaArtistBoxWidth)  ?? 0
        cortinaTitleBoxWidth   = try c.decodeIfPresent(Double.self, forKey: .cortinaTitleBoxWidth)   ?? 0
        nextUpLabelBoxWidth    = try c.decodeIfPresent(Double.self, forKey: .nextUpLabelBoxWidth)    ?? 0
        lastPlayedBoxWidth     = try c.decodeIfPresent(Double.self, forKey: .lastPlayedBoxWidth)     ?? 0

        // Per-element horizontal alignment — absent in older JSON, default to centre.
        titleHAlign          = try c.decodeIfPresent(TextHAlignment.self, forKey: .titleHAlign)          ?? .center
        artistHAlign         = try c.decodeIfPresent(TextHAlignment.self, forKey: .artistHAlign)         ?? .center
        genreHAlign          = try c.decodeIfPresent(TextHAlignment.self, forKey: .genreHAlign)          ?? .center
        yearHAlign           = try c.decodeIfPresent(TextHAlignment.self, forKey: .yearHAlign)           ?? .center
        singerHAlign         = try c.decodeIfPresent(TextHAlignment.self, forKey: .singerHAlign)         ?? .center
        trackCounterHAlign   = try c.decodeIfPresent(TextHAlignment.self, forKey: .trackCounterHAlign)   ?? .center
        lastTandaLabelHAlign = try c.decodeIfPresent(TextHAlignment.self, forKey: .lastTandaLabelHAlign) ?? .center
        cortinaLabelHAlign   = try c.decodeIfPresent(TextHAlignment.self, forKey: .cortinaLabelHAlign)   ?? .center
        cortinaArtistHAlign  = try c.decodeIfPresent(TextHAlignment.self, forKey: .cortinaArtistHAlign)  ?? .center
        cortinaTitleHAlign   = try c.decodeIfPresent(TextHAlignment.self, forKey: .cortinaTitleHAlign)   ?? .center
        nextUpLabelHAlign    = try c.decodeIfPresent(TextHAlignment.self, forKey: .nextUpLabelHAlign)    ?? .center
        lastPlayedHAlign     = try c.decodeIfPresent(TextHAlignment.self, forKey: .lastPlayedHAlign)     ?? .center

        // Coordinate-system migration. Older profiles stored offsets/box widths as absolute points and
        // had no `relativePositions` key. Convert them to percent of a 1920×1080 baseline and, to keep
        // the old look, left-align any element that had a non-zero horizontal offset (the previous
        // "offset → left-aligned" behaviour). Profiles already in percent are left untouched (idempotent).
        relativePositions = try c.decodeIfPresent(Bool.self, forKey: .relativePositions) ?? false
        if !relativePositions {
            if titleOffsetX          != 0 { titleHAlign = .leading }
            if artistOffsetX         != 0 { artistHAlign = .leading }
            if genreOffsetX          != 0 { genreHAlign = .leading }
            if yearOffsetX           != 0 { yearHAlign = .leading }
            if singerOffsetX         != 0 { singerHAlign = .leading }
            if trackCounterOffsetX   != 0 { trackCounterHAlign = .leading }
            if lastTandaLabelOffsetX != 0 { lastTandaLabelHAlign = .leading }
            if cortinaLabelOffsetX   != 0 { cortinaLabelHAlign = .leading }
            if cortinaArtistOffsetX  != 0 { cortinaArtistHAlign = .leading }
            if cortinaTitleOffsetX   != 0 { cortinaTitleHAlign = .leading }
            if nextUpLabelOffsetX    != 0 { nextUpLabelHAlign = .leading }
            if lastPlayedOffsetX     != 0 { lastPlayedHAlign = .leading }

            func relX(_ v: Double) -> Double { v / 1920.0 * 100.0 }
            func relY(_ v: Double) -> Double { v / 1080.0 * 100.0 }
            titleOffsetX = relX(titleOffsetX);                 titleOffsetY = relY(titleOffsetY)
            artistOffsetX = relX(artistOffsetX);               artistOffsetY = relY(artistOffsetY)
            genreOffsetX = relX(genreOffsetX);                 genreOffsetY = relY(genreOffsetY)
            yearOffsetX = relX(yearOffsetX);                   yearOffsetY = relY(yearOffsetY)
            singerOffsetX = relX(singerOffsetX);               singerOffsetY = relY(singerOffsetY)
            trackCounterOffsetX = relX(trackCounterOffsetX);   trackCounterOffsetY = relY(trackCounterOffsetY)
            lastTandaLabelOffsetX = relX(lastTandaLabelOffsetX); lastTandaLabelOffsetY = relY(lastTandaLabelOffsetY)
            cortinaLabelOffsetX = relX(cortinaLabelOffsetX);   cortinaLabelOffsetY = relY(cortinaLabelOffsetY)
            cortinaArtistOffsetX = relX(cortinaArtistOffsetX); cortinaArtistOffsetY = relY(cortinaArtistOffsetY)
            cortinaTitleOffsetX = relX(cortinaTitleOffsetX);   cortinaTitleOffsetY = relY(cortinaTitleOffsetY)
            nextUpLabelOffsetX = relX(nextUpLabelOffsetX);     nextUpLabelOffsetY = relY(nextUpLabelOffsetY)
            lastPlayedOffsetX = relX(lastPlayedOffsetX);       lastPlayedOffsetY = relY(lastPlayedOffsetY)
            titleBoxWidth = relX(titleBoxWidth);               artistBoxWidth = relX(artistBoxWidth)
            genreBoxWidth = relX(genreBoxWidth);               yearBoxWidth = relX(yearBoxWidth)
            singerBoxWidth = relX(singerBoxWidth);             trackCounterBoxWidth = relX(trackCounterBoxWidth)
            lastTandaLabelBoxWidth = relX(lastTandaLabelBoxWidth); cortinaLabelBoxWidth = relX(cortinaLabelBoxWidth)
            cortinaArtistBoxWidth = relX(cortinaArtistBoxWidth);   cortinaTitleBoxWidth = relX(cortinaTitleBoxWidth)
            nextUpLabelBoxWidth = relX(nextUpLabelBoxWidth)
            lastPlayedBoxWidth = relX(lastPlayedBoxWidth)
            relativePositions = true
        }

        // Font-size coordinate-system migration: older profiles stored absolute points and had no
        // `relativeFontSizes` key. Convert to a level (1–15 = percent of a 1080-tall baseline) and mark
        // relative. Idempotent: profiles already in levels are left untouched.
        relativeFontSizes = try c.decodeIfPresent(Bool.self, forKey: .relativeFontSizes) ?? false
        if !relativeFontSizes {
            func lvl(_ pts: Double) -> Double { min(15, max(1, (pts / 1080.0 * 100.0).rounded())) }
            titleFontSize = lvl(titleFontSize);                 artistFontSize = lvl(artistFontSize)
            genreFontSize = lvl(genreFontSize);                 yearFontSize = lvl(yearFontSize)
            singerFontSize = lvl(singerFontSize);               trackCounterFontSize = lvl(trackCounterFontSize)
            cortinaLabelFontSize = lvl(cortinaLabelFontSize);   cortinaArtistFontSize = lvl(cortinaArtistFontSize)
            cortinaTitleFontSize = lvl(cortinaTitleFontSize);   nextUpLabelFontSize = lvl(nextUpLabelFontSize)
            idleMessageFontSize = lvl(idleMessageFontSize);     lastTandaLabelFontSize = lvl(lastTandaLabelFontSize)
            overrideTextFontSize = lvl(overrideTextFontSize);   lastPlayedFontSize = lvl(lastPlayedFontSize)
            relativeFontSizes = true
        }

        // Album-artwork offset migration: older profiles stored points and had no
        // `relativeArtworkPosition` key. Convert to percent of a 1920×1080 baseline. Idempotent.
        relativeArtworkPosition = try c.decodeIfPresent(Bool.self, forKey: .relativeArtworkPosition) ?? false
        if !relativeArtworkPosition {
            albumArtworkOffsetX = albumArtworkOffsetX / 1920.0 * 100.0
            albumArtworkOffsetY = albumArtworkOffsetY / 1080.0 * 100.0
            relativeArtworkPosition = true
        }

        tdjNameColor      = try c.decodeIfPresent(String.self, forKey: .tdjNameColor)      ?? "#AAAAAA"
        tdjNameFontName   = try c.decodeIfPresent(String.self, forKey: .tdjNameFontName)   ?? "System"
        tdjNameFontSize   = try c.decodeIfPresent(Double.self, forKey: .tdjNameFontSize)   ?? 3
        tdjNameFontBold   = try c.decodeIfPresent(Bool.self,   forKey: .tdjNameFontBold)   ?? false
        tdjNameFontItalic = try c.decodeIfPresent(Bool.self,   forKey: .tdjNameFontItalic) ?? false
        tdjNameOffsetX    = try c.decodeIfPresent(Double.self, forKey: .tdjNameOffsetX)    ?? 0
        tdjNameOffsetY    = try c.decodeIfPresent(Double.self, forKey: .tdjNameOffsetY)    ?? 0
        tdjNameBoxWidth   = try c.decodeIfPresent(Double.self, forKey: .tdjNameBoxWidth)   ?? 0
        tdjNameHAlign     = try c.decodeIfPresent(TextHAlignment.self, forKey: .tdjNameHAlign) ?? .center

        // Layout mode — absent in older profiles (flow), unknown raw values from
        // newer versions fall back to flow rather than failing the decode.
        if let rawLayout = try c.decodeIfPresent(String.self, forKey: .layoutMode) {
            layoutMode = LayoutMode(rawValue: rawLayout) ?? .flow
        } else {
            layoutMode = .flow
        }

        // Migration: append items to order lists if absent
        if !danceItemOrder.contains(.lastTandaLabel) {
            danceItemOrder.append(.lastTandaLabel)
        }
        if !danceItemOrder.contains(.trackCounter) {
            danceItemOrder.append(.trackCounter)
        }
        if !cortinaItemOrder.contains(.lastTandaLabel) {
            cortinaItemOrder.append(.lastTandaLabel)
        }
        if !danceItemOrder.contains(.lastPlayed) {
            danceItemOrder.append(.lastPlayed)
        }
        if !cortinaItemOrder.contains(.lastPlayed) {
            cortinaItemOrder.append(.lastPlayed)
        }
        if !danceItemOrder.contains(.tdjName) {
            danceItemOrder.append(.tdjName)
        }
        if !cortinaItemOrder.contains(.tdjName) {
            cortinaItemOrder.append(.tdjName)
        }
    }

    public func singerValue(from track: Track) -> String? {
        switch singerSource {
        case .comments:    return track.comment
        case .albumArtist: return track.albumArtist
        case .grouping:    return track.grouping
        }
    }

    /// Returns the first artist background entry whose name is found within `artist` (partial,
    /// case-insensitive, diacritic-insensitive match). Returns nil when the feature is disabled
    /// or no entry matches.
    public func matchingArtistBackground(for artist: String) -> ArtistBackground? {
        guard artistBackgroundsEnabled else { return nil }
        let needle = artist.trimmingCharacters(in: .whitespaces)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return artistBackgrounds.first { entry in
            let key = entry.artistName.trimmingCharacters(in: .whitespaces)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            return !key.isEmpty && needle.contains(key)
        }
    }

    /// Resolves the genre-background image for the current track. Matching rules:
    /// - If the detector classifies the genre as a cortina, returns the cortina-sentinel entry.
    /// - Otherwise, looks for an entry whose genreKey matches the track's genre — exact case-insensitive
    ///   match, or a word-boundary substring match if that key is in the detector's partial-match set.
    /// Returns nil when the feature is disabled or no matching entry has an image.
    public func matchingGenreBackground(
        for trackGenre: String,
        using detector: CortinaDetector
    ) -> GenreBackground? {
        guard genreBackgroundsEnabled else { return nil }
        if detector.isCortina(genre: trackGenre) {
            return genreBackgrounds.first { $0.isCortinaEntry && $0.imageFilename != nil }
        }
        let needle = trackGenre.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return nil }
        for entry in genreBackgrounds where !entry.isCortinaEntry && entry.imageFilename != nil {
            let key = entry.genreKey.trimmingCharacters(in: .whitespaces).lowercased()
            if key.isEmpty { continue }
            if needle == key { return entry }
            if detector.denylistPartialGenres.contains(key),
               needle.hasPrefix(key + " ") || needle.contains(" " + key) {
                return entry
            }
        }
        return nil
    }

    public static let builtIns: [AppearanceProfile] = [.classic, .modern, .highContrast]

    public static let classic = AppearanceProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Classic", isBuiltIn: true,
        backgroundColor: "#1A1208",
        titleColor: "#F5E6C8", artistColor: "#F5E6C8", genreColor: "#C8A97A",
        trackCounterColor: "#C8A97A"
    )

    public static let modern = AppearanceProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Modern", isBuiltIn: true,
        backgroundColor: "#1C1C1E",
        titleColor: "#FFFFFF", artistColor: "#FFFFFF", genreColor: "#8E8E93",
        trackCounterColor: "#8E8E93"
    )

    public static let highContrast = AppearanceProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "High Contrast", isBuiltIn: true,
        backgroundColor: "#000000",
        titleColor: "#FFFF00", artistColor: "#FFFF00", genreColor: "#FFFFFF",
        trackCounterColor: "#B3B3B3",
        transitionStyle: .cut, transitionDuration: 0.0
    )
}

public enum DisplayTextItem: String, Codable, CaseIterable {
    case genre, artist, year, title, singer
    case cortinaLabel    // "CORTINA" heading text
    case cortinaArtist   // cortina track's own artist
    case cortinaTitle    // cortina track's own title
    case nextUpLabel     // "COMING UP" heading text
    case lastTandaLabel  // "LAST TANDA" announcement label
    case trackCounter    // rendered inline when position == .centre
    case lastPlayed      // previously played track ("Artist — Title")
    case tdjName         // the DJ's name; rendered inline when position == .centre

    public var displayName: String {
        switch self {
        case .genre:           "Genre"
        case .artist:          "Artist"
        case .year:            "Year"
        case .title:           "Title"
        case .singer:          "Singer"
        case .cortinaLabel:    "Cortina Label"
        case .cortinaArtist:   "Cortina Artist"
        case .cortinaTitle:    "Cortina Title"
        case .nextUpLabel:     "Next Up Label"
        case .lastTandaLabel:  "Last Tanda Label"
        case .trackCounter:    "Track Counter"
        case .lastPlayed:      "Last Played"
        case .tdjName:         "TDJ Name"
        }
    }
}

public enum GenreTextCase: String, Codable, CaseIterable {
    case uppercase
    case original
    case titleCase

    public var displayName: String {
        switch self {
        case .uppercase: "UPPERCASE"
        case .original:  "Original"
        case .titleCase: "Title Case"
        }
    }

    /// Applies the chosen casing to a genre label.
    public func apply(_ label: String) -> String {
        switch self {
        case .uppercase: return label.uppercased()
        case .original:  return label
        case .titleCase: return label.capitalized
        }
    }
}

public enum AlbumArtFadeStyle: String, Codable, CaseIterable {
    case radial   // circular fade toward the corners (historical default)
    case edges    // linear fade inset from all four edges

    public var displayName: String {
        switch self {
        case .radial: "Radial"
        case .edges:  "Edges"
        }
    }
}

public enum TextHAlignment: String, Codable, CaseIterable {
    case leading
    case center
    case trailing

    public var displayName: String {
        switch self {
        case .leading:  "Left"
        case .center:   "Centre"
        case .trailing: "Right"
        }
    }
}

public enum SingerSource: String, Codable, CaseIterable {
    case comments    = "comments"
    case albumArtist = "albumArtist"
    case grouping    = "grouping"

    public var displayName: String {
        switch self {
        case .comments:    "Comments"
        case .albumArtist: "Album Artist"
        case .grouping:    "Grouping"
        }
    }

    /// The track-info field this singer source reads from — lets the singer line go through the same
    /// display resolver as other fields (so an Advanced "copy from field" / regex rule applies).
    public var trackInfoField: TrackInfoField {
        switch self {
        case .comments:    .comments
        case .albumArtist: .albumArtist
        case .grouping:    .grouping
        }
    }
}

public enum TransitionStyle: String, Codable, CaseIterable {
    case fade
    case cut
    case fadeToBlack
    case push
    case zoom

    public var displayName: String {
        switch self {
        case .fade:        "Crossfade"
        case .cut:         "Hard Cut"
        case .fadeToBlack: "Fade Through Black"
        case .push:        "Push"
        case .zoom:        "Zoom"
        }
    }
}

