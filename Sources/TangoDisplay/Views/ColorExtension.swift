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

    var titleFont: Font  { font(name: titleFontName,  size: titleFontSize,  bold: titleFontBold,  italic: titleFontItalic) }
    var artistFont: Font { font(name: artistFontName, size: artistFontSize, bold: artistFontBold, italic: artistFontItalic) }
    var genreFont: Font  { font(name: genreFontName,  size: genreFontSize,  bold: genreFontBold,  italic: genreFontItalic) }
    var yearFont: Font   { font(name: yearFontName,   size: yearFontSize,   bold: yearFontBold,   italic: yearFontItalic) }
    var singerFont: Font        { font(name: singerFontName,       size: singerFontSize,       bold: singerFontBold,       italic: singerFontItalic) }
    var trackCounterFont: Font  { font(name: trackCounterFontName, size: trackCounterFontSize, bold: trackCounterFontBold, italic: trackCounterFontItalic) }

    var cortinaLabelSwiftUIColor:  Color { Color(hex: cortinaLabelColor) }
    var cortinaArtistSwiftUIColor: Color { Color(hex: cortinaArtistColor) }
    var cortinaTitleSwiftUIColor:  Color { Color(hex: cortinaTitleColor) }
    var nextUpLabelSwiftUIColor:    Color { Color(hex: nextUpLabelColor) }
    var idleMessageSwiftUIColor:    Color { Color(hex: idleMessageColor) }
    var lastTandaLabelSwiftUIColor: Color { Color(hex: lastTandaLabelColor) }

    var cortinaLabelFont:   Font { font(name: cortinaLabelFontName,   size: cortinaLabelFontSize,   bold: cortinaLabelFontBold,   italic: cortinaLabelFontItalic) }
    var cortinaArtistFont:  Font { font(name: cortinaArtistFontName,  size: cortinaArtistFontSize,  bold: cortinaArtistFontBold,  italic: cortinaArtistFontItalic) }
    var cortinaTitleFont:   Font { font(name: cortinaTitleFontName,   size: cortinaTitleFontSize,   bold: cortinaTitleFontBold,   italic: cortinaTitleFontItalic) }
    var nextUpLabelFont:    Font { font(name: nextUpLabelFontName,    size: nextUpLabelFontSize,    bold: nextUpLabelFontBold,    italic: nextUpLabelFontItalic) }
    var idleMessageFont:    Font { font(name: idleMessageFontName,    size: idleMessageFontSize,    bold: idleMessageFontBold,    italic: idleMessageFontItalic) }
    var lastTandaLabelFont: Font { font(name: lastTandaLabelFontName, size: lastTandaLabelFontSize, bold: lastTandaLabelFontBold, italic: lastTandaLabelFontItalic) }
    var overrideTextSwiftUIColor: Color { Color(hex: overrideTextColor) }
    var overrideTextFont: Font { font(name: overrideTextFontName, size: overrideTextFontSize, bold: overrideTextFontBold, italic: overrideTextFontItalic) }
}

extension View {
    /// Positions a presentation text element, mirroring the album-artwork offset behaviour.
    ///
    /// - A non-zero horizontal offset left-aligns the element so the offset measures its left edge;
    ///   a zero horizontal offset keeps the element centred (the historical default).
    /// - When `boxWidth > 0` and a horizontal offset is set, the text is constrained to that width and
    ///   auto-shrinks on a single line to fit between the left edge and the box end.
    /// - Otherwise `lineLimit`/`autoShrink` reproduce the element's normal multi-line behaviour.
    @ViewBuilder
    func positioned(offsetX: Double, offsetY: Double,
                    boxWidth: Double = 0, lineLimit: Int? = nil, autoShrink: Bool = false,
                    showBounds: Bool = false) -> some View {
        let shifted = offsetX != 0
        // Only positioned elements get a bounds outline (those with an offset or an explicit box).
        let drawBounds = showBounds && (offsetX != 0 || boxWidth > 0)
        if shifted && boxWidth > 0 {
            self
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .frame(width: boxWidth, alignment: .leading)
                .elementBoundsOverlay(drawBounds)
                .offset(x: offsetX, y: offsetY)
        } else {
            self
                .multilineTextAlignment(shifted ? .leading : .center)
                .lineLimit(lineLimit)
                .minimumScaleFactor(autoShrink ? 0.5 : 1)
                .frame(maxWidth: .infinity, alignment: shifted ? .leading : .center)
                .elementBoundsOverlay(drawBounds)
                .offset(x: offsetX, y: offsetY)
        }
    }

    /// Draws a dashed outline plus a point-size label around the element's layout frame. Used only in
    /// the configuration preview (never the real presentation display) so the DJ can see how big each
    /// positioned element / box actually is. Sizes are reported in presentation points (the preview's
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
