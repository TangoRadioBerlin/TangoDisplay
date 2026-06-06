import SwiftUI
import TangoDisplayCore

extension Color {
    /// Parses "#RRGGBB" or "#RRGGBBAA" hex strings.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8)  & 0xFF) / 255
            b = Double( rgb        & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((rgb >> 24) & 0xFF) / 255
            g = Double((rgb >> 16) & 0xFF) / 255
            b = Double((rgb >> 8)  & 0xFF) / 255
            a = Double( rgb        & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

extension AppearanceProfile {
    var backgroundSwiftUIColor: Color    { Color(hex: backgroundColor) }
    var titleSwiftUIColor: Color         { Color(hex: titleColor) }
    var artistSwiftUIColor: Color        { Color(hex: artistColor) }
    var genreSwiftUIColor: Color         { Color(hex: genreColor) }
    var yearSwiftUIColor: Color          { Color(hex: yearColor) }
    var trackCounterSwiftUIColor: Color  { Color(hex: trackCounterColor) }
    var singerSwiftUIColor: Color        { Color(hex: singerColor) }

    func font(name: String, size: Double, bold: Bool, italic: Bool) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        var f: Font
        if name == "System" || name.isEmpty {
            f = .system(size: size, weight: weight, design: .default)
        } else {
            f = .custom(name, size: size).weight(weight)
        }
        return italic ? f.italic() : f
    }

    // Font sizes are levels (percent of the presentation height); resolve to points with `h`.
    func titleFont(_ h: CGFloat) -> Font  { font(name: titleFontName,  size: titleFontSize  / 100 * Double(h), bold: titleFontBold,  italic: titleFontItalic) }
    func artistFont(_ h: CGFloat) -> Font { font(name: artistFontName, size: artistFontSize / 100 * Double(h), bold: artistFontBold, italic: artistFontItalic) }
    func genreFont(_ h: CGFloat) -> Font  { font(name: genreFontName,  size: genreFontSize  / 100 * Double(h), bold: genreFontBold,  italic: genreFontItalic) }
    func yearFont(_ h: CGFloat) -> Font   { font(name: yearFontName,   size: yearFontSize   / 100 * Double(h), bold: yearFontBold,   italic: yearFontItalic) }
    func singerFont(_ h: CGFloat) -> Font       { font(name: singerFontName,       size: singerFontSize       / 100 * Double(h), bold: singerFontBold,       italic: singerFontItalic) }
    func trackCounterFont(_ h: CGFloat) -> Font { font(name: trackCounterFontName, size: trackCounterFontSize / 100 * Double(h), bold: trackCounterFontBold, italic: trackCounterFontItalic) }

    var cortinaLabelSwiftUIColor:  Color { Color(hex: cortinaLabelColor) }
    var cortinaArtistSwiftUIColor: Color { Color(hex: cortinaArtistColor) }
    var cortinaTitleSwiftUIColor:  Color { Color(hex: cortinaTitleColor) }
    var nextUpLabelSwiftUIColor:    Color { Color(hex: nextUpLabelColor) }
    var idleMessageSwiftUIColor:    Color { Color(hex: idleMessageColor) }
    var lastTandaLabelSwiftUIColor: Color { Color(hex: lastTandaLabelColor) }
    var lastPlayedSwiftUIColor:     Color { Color(hex: lastPlayedColor) }

    func cortinaLabelFont(_ h: CGFloat) -> Font   { font(name: cortinaLabelFontName,   size: cortinaLabelFontSize   / 100 * Double(h), bold: cortinaLabelFontBold,   italic: cortinaLabelFontItalic) }
    func cortinaArtistFont(_ h: CGFloat) -> Font  { font(name: cortinaArtistFontName,  size: cortinaArtistFontSize  / 100 * Double(h), bold: cortinaArtistFontBold,  italic: cortinaArtistFontItalic) }
    func cortinaTitleFont(_ h: CGFloat) -> Font   { font(name: cortinaTitleFontName,   size: cortinaTitleFontSize   / 100 * Double(h), bold: cortinaTitleFontBold,   italic: cortinaTitleFontItalic) }
    func nextUpLabelFont(_ h: CGFloat) -> Font    { font(name: nextUpLabelFontName,    size: nextUpLabelFontSize    / 100 * Double(h), bold: nextUpLabelFontBold,    italic: nextUpLabelFontItalic) }
    func idleMessageFont(_ h: CGFloat) -> Font    { font(name: idleMessageFontName,    size: idleMessageFontSize    / 100 * Double(h), bold: idleMessageFontBold,    italic: idleMessageFontItalic) }
    func lastTandaLabelFont(_ h: CGFloat) -> Font { font(name: lastTandaLabelFontName, size: lastTandaLabelFontSize / 100 * Double(h), bold: lastTandaLabelFontBold, italic: lastTandaLabelFontItalic) }
    func lastPlayedFont(_ h: CGFloat) -> Font     { font(name: lastPlayedFontName,     size: lastPlayedFontSize     / 100 * Double(h), bold: lastPlayedFontBold,     italic: lastPlayedFontItalic) }
    var overrideTextSwiftUIColor: Color { Color(hex: overrideTextColor) }
    func overrideTextFont(_ h: CGFloat) -> Font { font(name: overrideTextFontName, size: overrideTextFontSize / 100 * Double(h), bold: overrideTextFontBold, italic: overrideTextFontItalic) }
}

extension View {
    /// Positions a presentation text element using resolution-relative coordinates.
    ///
    /// - `offsetX`/`offsetY` are percentages (−100…100) of the container's width/height: a relative
    ///   shift from the element's natural stacked position (0 = unchanged).
    /// - `boxWidth` is a percentage (0…100) of the container width. 0 = full width (no box).
    /// - `hAlign` controls the text's alignment within its box (or the full width when no box).
    /// - When a box is set, the text is constrained to that width and auto-shrinks on a single line.
    @ViewBuilder
    func positioned(offsetX: Double, offsetY: Double,
                    boxWidth: Double = 0, hAlign: TextHAlignment = .center,
                    lineLimit: Int? = nil, autoShrink: Bool = false,
                    showBounds: Bool = false, containerSize: CGSize) -> some View {
        let offX = offsetX / 100.0 * containerSize.width
        let offY = offsetY / 100.0 * containerSize.height
        let boxPts = boxWidth / 100.0 * containerSize.width
        let frameAlign: Alignment = hAlign == .leading ? .leading : (hAlign == .trailing ? .trailing : .center)
        let textAlign: TextAlignment = hAlign == .leading ? .leading : (hAlign == .trailing ? .trailing : .center)
        if boxPts > 0 {
            self
                .multilineTextAlignment(textAlign)
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .frame(width: boxPts, alignment: frameAlign)
                .elementBoundsOverlay(showBounds)
                .offset(x: offX, y: offY)
        } else {
            self
                .multilineTextAlignment(textAlign)
                .lineLimit(lineLimit)
                .minimumScaleFactor(autoShrink ? 0.5 : 1)
                .frame(maxWidth: .infinity, alignment: frameAlign)
                .elementBoundsOverlay(showBounds)
                .offset(x: offX, y: offY)
        }
    }

    /// Draws a dashed outline plus a point-size label around the element's layout frame. Used only in
    /// the configuration preview (never the real presentation display) so the DJ can see how big each
    /// element / box actually is. Sizes are reported in presentation points (the preview's
    /// 1920×1080 space, before the pane's down-scaling).
    @ViewBuilder
    func elementBoundsOverlay(_ draw: Bool) -> some View {
        if draw {
            self.overlay {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .strokeBorder(Color.accentColor.opacity(0.9),
                                          style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                        Text("\(Int(geo.size.width.rounded()))×\(Int(geo.size.height.rounded())) pt")
                            .font(.system(size: 26, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.9))
                            .padding(3)
                    }
                }
                .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}
