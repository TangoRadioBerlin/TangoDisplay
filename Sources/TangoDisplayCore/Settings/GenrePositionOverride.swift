import Foundation

/// Position/box/alignment for a single text element (resolution-relative, like the profile's flat fields).
public struct ElementPlacement: Codable, Equatable {
    public var offsetX: Double
    public var offsetY: Double
    public var boxWidth: Double
    public var hAlign: TextHAlignment

    public init(offsetX: Double = 0, offsetY: Double = 0,
                boxWidth: Double = 0, hAlign: TextHAlignment = .center) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.boxWidth = boxWidth
        self.hAlign = hAlign
    }
}

/// Album-artwork placement (offset/size/opacity in the same units as the profile's artwork fields:
/// offsets as percent of the resolution, scale as a multiplier, opacity 0…1).
public struct ArtworkPlacement: Codable, Equatable {
    public var offsetX: Double
    public var offsetY: Double
    public var scale: Double
    public var opacity: Double

    public init(offsetX: Double = 0, offsetY: Double = 0, scale: Double = 1, opacity: Double = 1) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.opacity = opacity
    }
}

/// Per-scene override for the artwork backing plate. Every field is optional:
/// nil inherits the profile value (colour) or follows the artwork offsets
/// (position) — exactly the pre-feature behaviour.
public struct PlatePlacement: Codable, Equatable {
    public var colorHex: String?
    public var offsetX: Double?
    public var offsetY: Double?

    public init(colorHex: String? = nil, offsetX: Double? = nil, offsetY: Double? = nil) {
        self.colorHex = colorHex
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    /// True when at least one field is actually overridden.
    public var hasContent: Bool { colorHex != nil || offsetX != nil || offsetY != nil }
}

/// A sparse per-element position override set, keyed by element name (see AppearanceProfile.positionElementKeys).
/// Elements absent from `placements` fall back to the profile's default position. `artwork` optionally
/// overrides the album-artwork placement for the genre, `plate` the artwork backing plate.
public struct PositionSet: Codable, Equatable {
    public var placements: [String: ElementPlacement]
    public var artwork: ArtworkPlacement?
    public var plate: PlatePlacement?

    public init(placements: [String: ElementPlacement] = [:], artwork: ArtworkPlacement? = nil,
                plate: PlatePlacement? = nil) {
        self.placements = placements
        self.artwork = artwork
        self.plate = plate
    }

    /// True when the set contains at least one real override. An empty PositionSet
    /// (all elements returned to base) should be treated as absent and set to nil (B6).
    /// A plate whose fields were all reset counts as absent too.
    public var hasContent: Bool { !placements.isEmpty || artwork != nil || plate?.hasContent == true }
}

extension AppearanceProfile {
    /// Canonical element keys that carry per-element position fields.
    public static let positionElementKeys: [String] = [
        "title", "artist", "genre", "year", "singer", "trackCounter",
        "lastTandaLabel", "cortinaLabel", "cortinaArtist", "cortinaTitle", "nextUpLabel", "lastPlayed", "tdjName"
    ]

    public static func positionElementDisplayName(_ key: String) -> String {
        switch key {
        case "title":          return "Title"
        case "artist":         return "Artist"
        case "genre":          return "Genre"
        case "year":           return "Year"
        case "singer":         return "Singer"
        case "trackCounter":   return "Track Counter"
        case "lastTandaLabel": return "Last Tanda Label"
        case "cortinaLabel":   return "Cortina Label"
        case "cortinaArtist":  return "Cortina Artist"
        case "cortinaTitle":   return "Cortina Title"
        case "nextUpLabel":    return "Next Up Label"
        case "lastPlayed":     return "Last Played"
        case "tdjName":        return "TDJ Name"
        default:               return key
        }
    }

    /// The profile's default placement (flat fields) for an element key.
    public func placement(forKey key: String) -> ElementPlacement {
        switch key {
        case "title":          return ElementPlacement(offsetX: titleOffsetX, offsetY: titleOffsetY, boxWidth: titleBoxWidth, hAlign: titleHAlign)
        case "artist":         return ElementPlacement(offsetX: artistOffsetX, offsetY: artistOffsetY, boxWidth: artistBoxWidth, hAlign: artistHAlign)
        case "genre":          return ElementPlacement(offsetX: genreOffsetX, offsetY: genreOffsetY, boxWidth: genreBoxWidth, hAlign: genreHAlign)
        case "year":           return ElementPlacement(offsetX: yearOffsetX, offsetY: yearOffsetY, boxWidth: yearBoxWidth, hAlign: yearHAlign)
        case "singer":         return ElementPlacement(offsetX: singerOffsetX, offsetY: singerOffsetY, boxWidth: singerBoxWidth, hAlign: singerHAlign)
        case "trackCounter":   return ElementPlacement(offsetX: trackCounterOffsetX, offsetY: trackCounterOffsetY, boxWidth: trackCounterBoxWidth, hAlign: trackCounterHAlign)
        case "lastTandaLabel": return ElementPlacement(offsetX: lastTandaLabelOffsetX, offsetY: lastTandaLabelOffsetY, boxWidth: lastTandaLabelBoxWidth, hAlign: lastTandaLabelHAlign)
        case "cortinaLabel":   return ElementPlacement(offsetX: cortinaLabelOffsetX, offsetY: cortinaLabelOffsetY, boxWidth: cortinaLabelBoxWidth, hAlign: cortinaLabelHAlign)
        case "cortinaArtist":  return ElementPlacement(offsetX: cortinaArtistOffsetX, offsetY: cortinaArtistOffsetY, boxWidth: cortinaArtistBoxWidth, hAlign: cortinaArtistHAlign)
        case "cortinaTitle":   return ElementPlacement(offsetX: cortinaTitleOffsetX, offsetY: cortinaTitleOffsetY, boxWidth: cortinaTitleBoxWidth, hAlign: cortinaTitleHAlign)
        case "nextUpLabel":    return ElementPlacement(offsetX: nextUpLabelOffsetX, offsetY: nextUpLabelOffsetY, boxWidth: nextUpLabelBoxWidth, hAlign: nextUpLabelHAlign)
        case "lastPlayed":     return ElementPlacement(offsetX: lastPlayedOffsetX, offsetY: lastPlayedOffsetY, boxWidth: lastPlayedBoxWidth, hAlign: lastPlayedHAlign)
        case "tdjName":        return ElementPlacement(offsetX: tdjNameOffsetX, offsetY: tdjNameOffsetY, boxWidth: tdjNameBoxWidth, hAlign: tdjNameHAlign)
        default:               return ElementPlacement()
        }
    }

    public mutating func setPlacement(_ p: ElementPlacement, forKey key: String) {
        switch key {
        case "title":          titleOffsetX = p.offsetX; titleOffsetY = p.offsetY; titleBoxWidth = p.boxWidth; titleHAlign = p.hAlign
        case "artist":         artistOffsetX = p.offsetX; artistOffsetY = p.offsetY; artistBoxWidth = p.boxWidth; artistHAlign = p.hAlign
        case "genre":          genreOffsetX = p.offsetX; genreOffsetY = p.offsetY; genreBoxWidth = p.boxWidth; genreHAlign = p.hAlign
        case "year":           yearOffsetX = p.offsetX; yearOffsetY = p.offsetY; yearBoxWidth = p.boxWidth; yearHAlign = p.hAlign
        case "singer":         singerOffsetX = p.offsetX; singerOffsetY = p.offsetY; singerBoxWidth = p.boxWidth; singerHAlign = p.hAlign
        case "trackCounter":   trackCounterOffsetX = p.offsetX; trackCounterOffsetY = p.offsetY; trackCounterBoxWidth = p.boxWidth; trackCounterHAlign = p.hAlign
        case "lastTandaLabel": lastTandaLabelOffsetX = p.offsetX; lastTandaLabelOffsetY = p.offsetY; lastTandaLabelBoxWidth = p.boxWidth; lastTandaLabelHAlign = p.hAlign
        case "cortinaLabel":   cortinaLabelOffsetX = p.offsetX; cortinaLabelOffsetY = p.offsetY; cortinaLabelBoxWidth = p.boxWidth; cortinaLabelHAlign = p.hAlign
        case "cortinaArtist":  cortinaArtistOffsetX = p.offsetX; cortinaArtistOffsetY = p.offsetY; cortinaArtistBoxWidth = p.boxWidth; cortinaArtistHAlign = p.hAlign
        case "cortinaTitle":   cortinaTitleOffsetX = p.offsetX; cortinaTitleOffsetY = p.offsetY; cortinaTitleBoxWidth = p.boxWidth; cortinaTitleHAlign = p.hAlign
        case "nextUpLabel":    nextUpLabelOffsetX = p.offsetX; nextUpLabelOffsetY = p.offsetY; nextUpLabelBoxWidth = p.boxWidth; nextUpLabelHAlign = p.hAlign
        case "lastPlayed":     lastPlayedOffsetX = p.offsetX; lastPlayedOffsetY = p.offsetY; lastPlayedBoxWidth = p.boxWidth; lastPlayedHAlign = p.hAlign
        case "tdjName":        tdjNameOffsetX = p.offsetX; tdjNameOffsetY = p.offsetY; tdjNameBoxWidth = p.boxWidth; tdjNameHAlign = p.hAlign
        default:               break
        }
    }

    /// The profile's current album-artwork placement.
    public func currentArtworkPlacement() -> ArtworkPlacement {
        ArtworkPlacement(offsetX: albumArtworkOffsetX, offsetY: albumArtworkOffsetY,
                         scale: albumArtworkScale, opacity: albumArtworkOpacity)
    }

    /// All current default placements as a PositionSet (used to seed a per-genre editor).
    public func currentPlacements() -> PositionSet {
        var dict: [String: ElementPlacement] = [:]
        for key in Self.positionElementKeys { dict[key] = placement(forKey: key) }
        return PositionSet(placements: dict, artwork: currentArtworkPlacement())
    }

    /// Returns a copy of this profile with the given override set applied to the flat position fields
    /// (and album-artwork placement). nil override → unchanged. Keeps the views' code unchanged.
    public func applyingPositionOverride(_ set: PositionSet?) -> AppearanceProfile {
        guard let set else { return self }
        var copy = self
        for (key, placement) in set.placements {
            copy.setPlacement(placement, forKey: key)
        }
        if let a = set.artwork {
            copy.albumArtworkOffsetX = a.offsetX
            copy.albumArtworkOffsetY = a.offsetY
            copy.albumArtworkScale = a.scale
            copy.albumArtworkOpacity = a.opacity
        }
        if let p = set.plate {
            if let color = p.colorHex { copy.albumArtworkBackingColor = color }
            if let x = p.offsetX { copy.albumArtworkBackingOffsetX = x }
            if let y = p.offsetY { copy.albumArtworkBackingOffsetY = y }
        }
        return copy
    }

    /// The position override for the current track's genre, if a matching genre-background entry carries one.
    /// Matching mirrors `matchingGenreBackground` but does not require an image.
    public func positionOverride(forGenre trackGenre: String, using detector: CortinaDetector) -> PositionSet? {
        guard genreBackgroundsEnabled else { return nil }
        if detector.isCortina(genre: trackGenre) {
            return genreBackgrounds.first { $0.isCortinaEntry }?.positions
        }
        let needle = trackGenre.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return nil }
        for entry in genreBackgrounds where !entry.isCortinaEntry {
            let key = entry.genreKey.trimmingCharacters(in: .whitespaces).lowercased()
            if key.isEmpty { continue }
            if needle == key { return entry.positions }
            if detector.denylistPartialGenres.contains(key),
               needle.hasPrefix(key + " ") || needle.contains(" " + key) {
                return entry.positions
            }
        }
        return nil
    }
}
