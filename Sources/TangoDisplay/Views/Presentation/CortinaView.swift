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

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Cortina-track section: CORTINA label always shown; artist/title gated by toggle
            VStack(spacing: 12) {
                ForEach(profile.cortinaTrackItemOrder, id: \.self) { item in
                    switch item {
                    case .cortinaLabel:
                        Text(settings.cortinaLabel)
                            .font(profile.cortinaLabelFont(containerSize.height))
                            .tracking(12)
                            .foregroundColor(profile.cortinaLabelSwiftUIColor)
                            .positioned(offsetX: profile.cortinaLabelOffsetX, offsetY: profile.cortinaLabelOffsetY,
                                        boxWidth: profile.cortinaLabelBoxWidth, hAlign: profile.cortinaLabelHAlign,
                                        showBounds: showBounds, containerSize: containerSize)
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
                                                showBounds: showBounds, containerSize: containerSize)
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
                                                showBounds: showBounds, containerSize: containerSize)
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
            }

            let showComingUp = profile.showNextTrackDuringCortina && state.nextTrack != nil
            let showLastTanda = isLastTandaActive && profile.showLastTandaLabel && !settings.lastTandaLabel.isEmpty
            let showLastPlayedC = profile.showLastPlayedCortina && lastPlayedTrack != nil
            if showComingUp || showLastTanda || showLastPlayedC {
                // Divider between cortina section and coming-up section
                Rectangle()
                    .fill(profile.genreSwiftUIColor.opacity(0.3))
                    .frame(width: 120, height: 1)
                    .padding(.vertical, 8)

                // Coming-up section
                VStack(spacing: 12) {
                    ForEach(profile.cortinaItemOrder, id: \.self) { item in
                        switch item {
                        case .nextUpLabel:
                            if showComingUp {
                                Text(settings.nextUpLabel)
                                    .font(profile.nextUpLabelFont(containerSize.height))
                                    .tracking(4)
                                    .foregroundColor(profile.nextUpLabelSwiftUIColor)
                                    .positioned(offsetX: profile.nextUpLabelOffsetX, offsetY: profile.nextUpLabelOffsetY,
                                                boxWidth: profile.nextUpLabelBoxWidth, hAlign: profile.nextUpLabelHAlign,
                                                showBounds: showBounds, containerSize: containerSize)
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
                                let displayYear = settings.effectiveValue(of: .year, from: next)
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
                                let lpText = settings.effectiveValue(of: .artist, from: lp)
                                    + " — " + settings.effectiveValue(of: .title, from: lp)
                                Text(lpText)
                                    .font(profile.lastPlayedFont(containerSize.height))
                                    .foregroundColor(profile.lastPlayedSwiftUIColor)
                                    .positioned(offsetX: profile.lastPlayedOffsetX, offsetY: profile.lastPlayedOffsetY,
                                                boxWidth: profile.lastPlayedBoxWidth, hAlign: profile.lastPlayedHAlign,
                                                lineLimit: 2, autoShrink: true,
                                                showBounds: showBounds, containerSize: containerSize)
                            }
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding(.horizontal, 60)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
