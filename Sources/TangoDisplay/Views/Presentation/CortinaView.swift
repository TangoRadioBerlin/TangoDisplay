import SwiftUI
import TangoDisplayCore

struct CortinaView: View {
    let state: DisplayState
    let profile: AppearanceProfile
    let isLastTandaActive: Bool
    @ObservedObject var settings: AppSettings
    var lastPlayedTrack: Track? = nil
    var showBounds: Bool = false
    var containerSize: CGSize = .zero

    private var perfCortinaLines: [PerformanceTextLine] {
        settings.performanceTextLines.filter { $0.showDuringCortina }
    }
    private var showPerformanceComing: Bool {
        state.nextTrackIsPerformance && !perfCortinaLines.isEmpty
    }
    private var showComingUp: Bool {
        profile.showNextTrackDuringCortina && state.nextTrack != nil && !showPerformanceComing
    }
    private var showLastTanda: Bool {
        isLastTandaActive && profile.showLastTandaLabel && !settings.lastTandaLabel.isEmpty
    }
    private var showLastPlayedC: Bool {
        profile.showLastPlayedCortina && lastPlayedTrack != nil
    }

    var body: some View {
        Group {
            if profile.layoutMode == .absolute {
                // Each element anchors at screen centre + its own offset, so an empty
                // field never shifts its neighbours. No divider — placement is free.
                ZStack {
                    ForEach(profile.cortinaTrackItemOrder, id: \.self) { item in
                        cortinaTrackItem(item)
                    }
                    cortinaYearView
                    performanceComingView
                    ForEach(profile.cortinaItemOrder, id: \.self) { item in
                        comingUpItem(item)
                    }
                }
                .padding(.horizontal, 60)
            } else {
                VStack(spacing: 32) {
                    Spacer()

                    // Cortina-track section: CORTINA label always shown; artist/title gated by toggle
                    VStack(spacing: 12) {
                        ForEach(profile.cortinaTrackItemOrder, id: \.self) { item in
                            cortinaTrackItem(item)
                        }
                        cortinaYearView
                    }

                    if showPerformanceComing || showComingUp || showLastTanda || showLastPlayedC {
                        // Divider between cortina section and coming-up section
                        Rectangle()
                            .fill(profile.genreSwiftUIColor.opacity(0.3))
                            .frame(width: 120, height: 1)
                            .padding(.vertical, 8)

                        // Coming-up section
                        VStack(spacing: 12) {
                            performanceComingView
                            ForEach(profile.cortinaItemOrder, id: \.self) { item in
                                comingUpItem(item)
                            }
                        }
                        .padding(.horizontal, 60)
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func cortinaTrackItem(_ item: DisplayTextItem) -> some View {
        switch item {
        case .cortinaLabel:
            if profile.showCortinaLabel {
                Text(settings.cortinaLabel)
                    .font(profile.cortinaLabelFont(containerSize.height))
                    .tracking(12)
                    .foregroundColor(profile.cortinaLabelSwiftUIColor)
                    .positioned(offsetX: profile.cortinaLabelOffsetX, offsetY: profile.cortinaLabelOffsetY,
                                boxWidth: profile.cortinaLabelBoxWidth, hAlign: profile.cortinaLabelHAlign,
                                showBounds: showBounds, containerSize: containerSize, measureKey: "cortinaLabel")
            }
        case .cortinaArtist:
            if profile.showCortinaTrackDuringCortina,
               profile.showCortinaTrackArtist,
               let track = state.currentTrack {
                let displayArtist = settings.effectiveValue(of: .artist, from: track)
                if !displayArtist.isEmpty {
                    Text(displayArtist)
                        .font(profile.cortinaArtistFont(containerSize.height))
                        .foregroundColor(profile.cortinaArtistSwiftUIColor)
                        .positioned(offsetX: profile.cortinaArtistOffsetX, offsetY: profile.cortinaArtistOffsetY,
                                    boxWidth: profile.cortinaArtistBoxWidth, hAlign: profile.cortinaArtistHAlign,
                                    lineLimit: 2, autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize, measureKey: "cortinaArtist")
                }
            }
        case .cortinaTitle:
            if profile.showCortinaTrackDuringCortina,
               profile.showCortinaTrackTitle,
               let track = state.currentTrack {
                let displayTitle = settings.effectiveValue(of: .title, from: track)
                if !displayTitle.isEmpty {
                    Text(displayTitle)
                        .font(profile.cortinaTitleFont(containerSize.height))
                        .foregroundColor(profile.cortinaTitleSwiftUIColor)
                        .positioned(offsetX: profile.cortinaTitleOffsetX, offsetY: profile.cortinaTitleOffsetY,
                                    boxWidth: profile.cortinaTitleBoxWidth, hAlign: profile.cortinaTitleHAlign,
                                    lineLimit: 2, autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize, measureKey: "cortinaTitle")
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var cortinaYearView: some View {
        if profile.showCortinaTrackDuringCortina, profile.showCortinaTrackYear,
           let track = state.currentTrack {
            let rawYear = settings.effectiveValue(of: .year, from: track)
            let displayYear = (!rawYear.isEmpty && profile.yearInParentheses) ? "(\(rawYear))" : rawYear
            if !displayYear.isEmpty {
                Text(displayYear)
                    .font(profile.yearFont(containerSize.height))
                    .foregroundColor(profile.yearSwiftUIColor)
                    .positioned(offsetX: profile.yearOffsetX, offsetY: profile.yearOffsetY,
                                boxWidth: profile.yearBoxWidth, hAlign: profile.yearHAlign,
                                showBounds: showBounds, containerSize: containerSize)
            }
        }
    }

    /// Pre-announces a performance: replaces the normal coming-up details with the
    /// DJ-configured performance lines (those marked "show during cortina").
    @ViewBuilder
    private var performanceComingView: some View {
        if showPerformanceComing {
            VStack(spacing: 12) {
                if !settings.nextUpLabel.isEmpty {
                    Text(settings.nextUpLabel)
                        .font(profile.nextUpLabelFont(containerSize.height))
                        .tracking(4)
                        .foregroundColor(profile.nextUpLabelSwiftUIColor)
                }
                ForEach(perfCortinaLines) { line in
                    let resolved = resolvePerformancePlaceholders(line.text, track: state.nextTrack)
                    if !resolved.isEmpty {
                        Text(resolved)
                            .font(performanceLineFont(line))
                            .foregroundColor(Color(hex: line.colorHex))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    }
                }
            }
        }
    }

    private func performanceLineFont(_ line: PerformanceTextLine) -> Font {
        if line.fontName == "System" || line.fontName.isEmpty {
            return .system(size: line.fontSize)
        }
        return .custom(line.fontName, size: line.fontSize)
    }

    @ViewBuilder
    private func comingUpItem(_ item: DisplayTextItem) -> some View {
        switch item {
        case .nextUpLabel:
            if showComingUp {
                Text(settings.nextUpLabel)
                    .font(profile.nextUpLabelFont(containerSize.height))
                    .tracking(4)
                    .foregroundColor(profile.nextUpLabelSwiftUIColor)
                    .positioned(offsetX: profile.nextUpLabelOffsetX, offsetY: profile.nextUpLabelOffsetY,
                                boxWidth: profile.nextUpLabelBoxWidth, hAlign: profile.nextUpLabelHAlign,
                                showBounds: showBounds, containerSize: containerSize, measureKey: "nextUpLabel")
            }
        case .genre:
            if showComingUp, let next = state.nextTrack,
               profile.showGenreCortina, !next.genre.isEmpty {
                Text(profile.genreTextCase.apply(settings.displayLabel(for: next.genre)))
                    .font(profile.genreFont(containerSize.height))
                    .foregroundColor(profile.genreSwiftUIColor)
                    .positioned(offsetX: profile.genreOffsetX, offsetY: profile.genreOffsetY,
                                boxWidth: profile.genreBoxWidth, hAlign: profile.genreHAlign,
                                showBounds: showBounds, containerSize: containerSize)
            }
        case .artist:
            if showComingUp, let next = state.nextTrack, profile.showArtistCortina {
                let displayArtist = settings.effectiveValue(of: .artist, from: next)
                if !displayArtist.isEmpty {
                    Text(displayArtist)
                        .font(profile.artistFont(containerSize.height))
                        .foregroundColor(profile.artistSwiftUIColor)
                        .positioned(offsetX: profile.artistOffsetX, offsetY: profile.artistOffsetY,
                                    boxWidth: profile.artistBoxWidth, hAlign: profile.artistHAlign,
                                    lineLimit: 2, autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize)
                }
            }
        case .year:
            if showComingUp, let next = state.nextTrack, profile.showYearCortina {
                let rawYear = settings.effectiveValue(of: .year, from: next)
                let displayYear = (!rawYear.isEmpty && profile.yearInParentheses) ? "(\(rawYear))" : rawYear
                if !displayYear.isEmpty {
                    Text(displayYear)
                        .font(profile.yearFont(containerSize.height))
                        .foregroundColor(profile.yearSwiftUIColor)
                        .positioned(offsetX: profile.yearOffsetX, offsetY: profile.yearOffsetY,
                                    boxWidth: profile.yearBoxWidth, hAlign: profile.yearHAlign,
                                    showBounds: showBounds, containerSize: containerSize)
                }
            }
        case .title:
            if showComingUp, let next = state.nextTrack, profile.showTitleCortina {
                let displayTitle = settings.effectiveValue(of: .title, from: next)
                if !displayTitle.isEmpty {
                    Text(displayTitle)
                        .font(profile.titleFont(containerSize.height))
                        .foregroundColor(profile.titleSwiftUIColor)
                        .positioned(offsetX: profile.titleOffsetX, offsetY: profile.titleOffsetY,
                                    boxWidth: profile.titleBoxWidth, hAlign: profile.titleHAlign,
                                    lineLimit: 2, autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize)
                }
            }
        case .singer:
            if showComingUp, let next = state.nextTrack, profile.showSingerCortina {
                let singer = settings.effectiveValue(of: profile.singerSource.trackInfoField, from: next)
                if !singer.isEmpty {
                    Text(singer)
                        .font(profile.singerFont(containerSize.height))
                        .foregroundColor(profile.singerSwiftUIColor)
                        .positioned(offsetX: profile.singerOffsetX, offsetY: profile.singerOffsetY,
                                    boxWidth: profile.singerBoxWidth, hAlign: profile.singerHAlign,
                                    lineLimit: 2, autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize)
                }
            }
        case .lastTandaLabel:
            if showLastTanda {
                Text(settings.lastTandaLabel.uppercased())
                    .font(profile.lastTandaLabelFont(containerSize.height))
                    .foregroundColor(profile.lastTandaLabelSwiftUIColor)
                    .positioned(offsetX: profile.lastTandaLabelOffsetX, offsetY: profile.lastTandaLabelOffsetY,
                                boxWidth: profile.lastTandaLabelBoxWidth, hAlign: profile.lastTandaLabelHAlign,
                                showBounds: showBounds, containerSize: containerSize)
            }
        case .lastPlayed:
            if profile.showLastPlayedCortina, let lp = lastPlayedTrack {
                let lpText = settings.lastPlayedPrefix + settings.effectiveValue(of: .title, from: lp)
                Text(lpText)
                    .font(profile.lastPlayedFont(containerSize.height))
                    .foregroundColor(profile.lastPlayedSwiftUIColor)
                    .positioned(offsetX: profile.lastPlayedOffsetX, offsetY: profile.lastPlayedOffsetY,
                                boxWidth: profile.lastPlayedBoxWidth, hAlign: profile.lastPlayedHAlign,
                                lineLimit: 2, autoShrink: true,
                                showBounds: showBounds, containerSize: containerSize)
            }
        case .tdjName:
            if settings.showTdjName,
               settings.tdjNamePosition == .centre,
               !settings.tdjName.isEmpty,
               settings.tdjNameVisibility.isVisible(in: .cortina) {
                Text(settings.tdjName)
                    .font(profile.tdjNameFont(containerSize.height))
                    .foregroundColor(profile.tdjNameSwiftUIColor)
                    .positioned(offsetX: profile.tdjNameOffsetX, offsetY: profile.tdjNameOffsetY,
                                boxWidth: profile.tdjNameBoxWidth, hAlign: profile.tdjNameHAlign,
                                showBounds: showBounds, containerSize: containerSize)
            }
        default:
            EmptyView()
        }
    }
}
