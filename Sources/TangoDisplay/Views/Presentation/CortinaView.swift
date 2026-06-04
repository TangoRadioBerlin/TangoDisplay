import SwiftUI
import TangoDisplayCore

struct CortinaView: View {
    let state: DisplayState
    let profile: AppearanceProfile
    let isLastTandaActive: Bool
    @ObservedObject var settings: AppSettings
    var showBounds: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Cortina-track section: CORTINA label always shown; artist/title gated by toggle
            VStack(spacing: 12) {
                ForEach(profile.cortinaTrackItemOrder, id: \.self) { item in
                    switch item {
                    case .cortinaLabel:
                        Text(settings.cortinaLabel)
                            .font(profile.cortinaLabelFont)
                            .tracking(12)
                            .foregroundColor(profile.cortinaLabelSwiftUIColor)
                            .positioned(offsetX: profile.cortinaLabelOffsetX, offsetY: profile.cortinaLabelOffsetY,
                                        boxWidth: profile.cortinaLabelBoxWidth, showBounds: showBounds)
                    case .cortinaArtist:
                        if profile.showCortinaTrackDuringCortina,
                           profile.showCortinaTrackArtist,
                           let track = state.currentTrack {
                            let displayArtist = settings.effectiveValue(of: .artist, from: track)
                            if !displayArtist.isEmpty {
                                Text(displayArtist)
                                    .font(profile.cortinaArtistFont)
                                    .foregroundColor(profile.cortinaArtistSwiftUIColor)
                                    .positioned(offsetX: profile.cortinaArtistOffsetX, offsetY: profile.cortinaArtistOffsetY,
                                                boxWidth: profile.cortinaArtistBoxWidth, lineLimit: 2, autoShrink: true,
                                                showBounds: showBounds)
                            }
                        }
                    case .cortinaTitle:
                        if profile.showCortinaTrackDuringCortina,
                           profile.showCortinaTrackTitle,
                           let track = state.currentTrack {
                            let displayTitle = settings.effectiveValue(of: .title, from: track)
                            if !displayTitle.isEmpty {
                                Text(displayTitle)
                                    .font(profile.cortinaTitleFont)
                                    .foregroundColor(profile.cortinaTitleSwiftUIColor)
                                    .positioned(offsetX: profile.cortinaTitleOffsetX, offsetY: profile.cortinaTitleOffsetY,
                                                boxWidth: profile.cortinaTitleBoxWidth, lineLimit: 2, autoShrink: true,
                                                showBounds: showBounds)
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
            }

            let showComingUp = profile.showNextTrackDuringCortina && state.nextTrack != nil
            let showLastTanda = isLastTandaActive && profile.showLastTandaLabel && !settings.lastTandaLabel.isEmpty
            if showComingUp || showLastTanda {
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
                                    .font(profile.nextUpLabelFont)
                                    .tracking(4)
                                    .foregroundColor(profile.nextUpLabelSwiftUIColor)
                                    .positioned(offsetX: profile.nextUpLabelOffsetX, offsetY: profile.nextUpLabelOffsetY,
                                                boxWidth: profile.nextUpLabelBoxWidth, showBounds: showBounds)
                            }
                        case .genre:
                            if showComingUp, let next = state.nextTrack,
                               profile.showGenreCortina, !next.genre.isEmpty {
                                Text(settings.displayLabel(for: next.genre))
                                    .font(profile.genreFont)
                                    .foregroundColor(profile.genreSwiftUIColor)
                                    .positioned(offsetX: profile.genreOffsetX, offsetY: profile.genreOffsetY,
                                                boxWidth: profile.genreBoxWidth, showBounds: showBounds)
                            }
                        case .artist:
                            if showComingUp, let next = state.nextTrack, profile.showArtistCortina {
                                let displayArtist = settings.effectiveValue(of: .artist, from: next)
                                if !displayArtist.isEmpty {
                                    Text(displayArtist)
                                        .font(profile.artistFont)
                                        .foregroundColor(profile.artistSwiftUIColor)
                                        .positioned(offsetX: profile.artistOffsetX, offsetY: profile.artistOffsetY,
                                                    boxWidth: profile.artistBoxWidth, lineLimit: 2, autoShrink: true,
                                                    showBounds: showBounds)
                                }
                            }
                        case .year:
                            if showComingUp, let next = state.nextTrack, profile.showYearCortina {
                                let displayYear = settings.effectiveValue(of: .year, from: next)
                                if !displayYear.isEmpty {
                                    Text(displayYear)
                                        .font(profile.yearFont)
                                        .foregroundColor(profile.yearSwiftUIColor)
                                        .positioned(offsetX: profile.yearOffsetX, offsetY: profile.yearOffsetY,
                                                    boxWidth: profile.yearBoxWidth, showBounds: showBounds)
                                }
                            }
                        case .title:
                            if showComingUp, let next = state.nextTrack, profile.showTitleCortina {
                                let displayTitle = settings.effectiveValue(of: .title, from: next)
                                if !displayTitle.isEmpty {
                                    Text(displayTitle)
                                        .font(profile.titleFont)
                                        .foregroundColor(profile.titleSwiftUIColor)
                                        .positioned(offsetX: profile.titleOffsetX, offsetY: profile.titleOffsetY,
                                                    boxWidth: profile.titleBoxWidth, lineLimit: 2, autoShrink: true,
                                                    showBounds: showBounds)
                                }
                            }
                        case .singer:
                            if showComingUp, let next = state.nextTrack, profile.showSingerCortina {
                                let singer = settings.effectiveValue(of: profile.singerSource.trackInfoField, from: next)
                                if !singer.isEmpty {
                                    Text(singer)
                                        .font(profile.singerFont)
                                        .foregroundColor(profile.singerSwiftUIColor)
                                        .positioned(offsetX: profile.singerOffsetX, offsetY: profile.singerOffsetY,
                                                    boxWidth: profile.singerBoxWidth, lineLimit: 2, autoShrink: true,
                                                    showBounds: showBounds)
                                }
                            }
                        case .lastTandaLabel:
                            if showLastTanda {
                                Text(settings.lastTandaLabel.uppercased())
                                    .font(profile.lastTandaLabelFont)
                                    .foregroundColor(profile.lastTandaLabelSwiftUIColor)
                                    .positioned(offsetX: profile.lastTandaLabelOffsetX, offsetY: profile.lastTandaLabelOffsetY,
                                                boxWidth: profile.lastTandaLabelBoxWidth, showBounds: showBounds)
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
