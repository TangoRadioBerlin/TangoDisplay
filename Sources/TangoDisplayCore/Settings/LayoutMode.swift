import Foundation

/// How the presentation views place text elements.
///
/// - `flow`: elements stack vertically (centred VStack); the per-element offset
///   percentages shift each element away from its flow position. An element that
///   is empty for the current track drops out of the stack, so its neighbours
///   move — the historical behaviour.
/// - `absolute`: every element is anchored independently at screen-centre plus
///   its offset percentages. Empty elements simply don't render and never move
///   their neighbours.
public enum LayoutMode: String, Codable, CaseIterable {
    case flow
    case absolute

    public var displayName: String {
        switch self {
        case .flow:     "Stacked (flow)"
        case .absolute: "Absolute"
        }
    }
}

/// An element's measured centre in container coordinates (origin top-left),
/// taken from the flow rendering *before* the element's own offset is applied.
public struct ElementCenter: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

extension AppearanceProfile {
    /// A copy with every dance text field forced visible. Used to measure the flow
    /// position of fields that are hidden in the live profile (year/singer default to
    /// hidden) so the flow→absolute conversion can still anchor them — otherwise a
    /// later-enabled field collapses onto screen centre. Does not touch the artwork.
    public func withAllDanceFieldsVisible() -> AppearanceProfile {
        var copy = self
        copy.showGenreDance     = true
        copy.showArtistDance    = true
        copy.showYearDance      = true
        copy.showTitleDance     = true
        copy.showSingerDance    = true
        copy.showLastPlayedDance = true
        copy.showLastTandaLabel  = true
        return copy
    }

    /// Returns a copy of this profile switched to absolute layout, seeded so the
    /// presentation initially looks identical to the measured flow rendering:
    /// each measured element's flow centre (pre-offset) becomes part of its offset,
    /// anchoring it from screen centre. Genre position overrides shift by the same
    /// per-element delta (an approximation — their flow base may differ per track).
    /// Already-absolute profiles are returned unchanged.
    /// - Parameters:
    ///   - measuredCenters: each element's flow centre as rendered with the profile's
    ///     *actual* field visibility — visible fields keep their current look.
    ///   - fallbackCenters: each element's flow centre from an *all-fields-visible*
    ///     measurement. Fields hidden at conversion time (year/singer default to hidden)
    ///     are absent from `measuredCenters`; without a fallback they would keep offset
    ///     (0,0) = screen centre and collide with other centred fields once shown. The
    ///     fallback gives them a real anchor. Actual measurements take precedence.
    public func convertedToAbsoluteLayout(measuredCenters: [String: ElementCenter],
                                          fallbackCenters: [String: ElementCenter] = [:],
                                          containerWidth: Double,
                                          containerHeight: Double) -> AppearanceProfile {
        guard layoutMode == .flow else { return self }

        // Visible fields (actual measurement) win; hidden fields fall back to their
        // all-visible position instead of collapsing to centre.
        let effectiveCenters = fallbackCenters.merging(measuredCenters) { _, actual in actual }

        var deltas: [String: (dx: Double, dy: Double)] = [:]
        var adjusted: [String: ElementPlacement] = [:]
        for (key, center) in effectiveCenters {
            let dx = AbsoluteLayoutMath.offsetXPercent(centerX: center.x, containerWidth: containerWidth)
            let dy = AbsoluteLayoutMath.offsetYPercent(centerY: center.y, containerHeight: containerHeight)
            deltas[key] = (dx, dy)
            var p = placement(forKey: key)
            p.offsetX += dx
            p.offsetY += dy
            adjusted[key] = p
        }

        var copy = applyingPositionOverride(PositionSet(placements: adjusted, artwork: nil))
        for bgIdx in copy.genreBackgrounds.indices {
            guard var set = copy.genreBackgrounds[bgIdx].positions else { continue }
            for (key, delta) in deltas {
                guard var p = set.placements[key] else { continue }
                p.offsetX += delta.dx
                p.offsetY += delta.dy
                set.placements[key] = p
            }
            copy.genreBackgrounds[bgIdx].positions = set
        }
        copy.layoutMode = .absolute
        return copy
    }
}

/// Pure conversion math for switching a profile from flow to absolute layout:
/// the preview measures each element's rendered centre, and these helpers turn
/// that into the offset percentages the `positioned()` modifier expects
/// (offset/100 × container, applied from screen centre).
public enum AbsoluteLayoutMath {
    public static func offsetXPercent(centerX: Double, containerWidth: Double) -> Double {
        guard containerWidth > 0 else { return 0 }
        return (centerX - containerWidth / 2.0) / containerWidth * 100.0
    }

    public static func offsetYPercent(centerY: Double, containerHeight: Double) -> Double {
        guard containerHeight > 0 else { return 0 }
        return (centerY - containerHeight / 2.0) / containerHeight * 100.0
    }
}
