import SwiftUI
import TangoDisplayCore

struct PlayingView: View {
    let state: DisplayState
    let profile: AppearanceProfile
    let isLastTandaActive: Bool
    @ObservedObject var settings: AppSettings
    var showBounds: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ForEach(profile.danceItemOrder, id: \.self) { item in
                switch item {
                case .genre:
                    if profile.showGenreDance, let genre = state.currentTrack?.genre, !genre.isEmpty {
                        Text(settings.displayLabel(for: genre).uppercased())
                            .font(profile.genreFont)
                            .foregroundColor(profile.genreSwiftUIColor)
                            .positioned(offsetX: profile.genreOffsetX, offsetY: profile.genreOffsetY,
                                        boxWidth: profile.genreBoxWidth, showBounds: showBounds)
                    }
                case .artist:
                    if profile.showArtistDance, let track = state.currentTrack {
                        let displayArtist = settings.effectiveValue(of: .artist, from: track)
                        if !displayArtist.isEmpty {
                            Text(displayArtist)
                                .font(profile.artistFont)
                                .foregroundColor(profile.artistSwiftUIColor)
                                .positioned(offsetX: profile.artistOffsetX, offsetY: profile.artistOffsetY,
                                            boxWidth: profile.artistBoxWidth,
                                            lineLimit: Self.dynamicLineLimit(displayArtist), autoShrink: true,
                                            showBounds: showBounds)
                        }
                    }
                case .year:
                    if profile.showYearDance, let track = state.currentTrack {
                        let displayYear = settings.effectiveValue(of: .year, from: track)
                        if !displayYear.isEmpty {
                            Text(displayYear)
                                .font(profile.yearFont)
                                .foregroundColor(profile.yearSwiftUIColor)
                                .positioned(offsetX: profile.yearOffsetX, offsetY: profile.yearOffsetY,
                                            boxWidth: profile.yearBoxWidth, showBounds: showBounds)
                        }
                    }
                case .title:
                    if profile.showTitleDance, let track = state.currentTrack {
                        let displayTitle = settings.effectiveValue(of: .title, from: track)
                        if !displayTitle.isEmpty {
                            Text(displayTitle)
                                .font(profile.titleFont)
                                .foregroundColor(profile.titleSwiftUIColor)
                                .positioned(offsetX: profile.titleOffsetX, offsetY: profile.titleOffsetY,
                                            boxWidth: profile.titleBoxWidth,
                                            lineLimit: Self.dynamicLineLimit(displayTitle), autoShrink: true,
                                            showBounds: showBounds)
                        }
                    }
                case .singer:
                    if profile.showSingerDance, let track = state.currentTrack {
                        let singer = settings.effectiveValue(of: profile.singerSource.trackInfoField, from: track)
                        if !singer.isEmpty {
                            Text(singer)
                                .font(profile.singerFont)
                                .foregroundColor(profile.singerSwiftUIColor)
                                .positioned(offsetX: profile.singerOffsetX, offsetY: profile.singerOffsetY,
                                            boxWidth: profile.singerBoxWidth,
                                            lineLimit: Self.dynamicLineLimit(singer), autoShrink: true,
                                            showBounds: showBounds)
                        }
                    }
                case .lastTandaLabel:
                    if profile.showLastTandaLabel, isLastTandaActive, !settings.lastTandaLabel.isEmpty {
                        Text(settings.lastTandaLabel.uppercased())
                            .font(profile.lastTandaLabelFont)
                            .foregroundColor(profile.lastTandaLabelSwiftUIColor)
                            .positioned(offsetX: profile.lastTandaLabelOffsetX, offsetY: profile.lastTandaLabelOffsetY,
                                        boxWidth: profile.lastTandaLabelBoxWidth, showBounds: showBounds)
                    }
                case .trackCounter:
                    if settings.showTrackCounter,
                       settings.trackCounterPosition == .centre,
                       let pos = state.tandaPosition {
                        Text(pos.label)
                            .font(profile.trackCounterFont)
                            .foregroundColor(profile.trackCounterSwiftUIColor)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                            .positioned(offsetX: profile.trackCounterOffsetX, offsetY: profile.trackCounterOffsetY,
                                        boxWidth: profile.trackCounterBoxWidth, showBounds: showBounds)
                    }
                case .cortinaLabel, .cortinaArtist, .cortinaTitle, .nextUpLabel:
                    EmptyView()
                }
            }

            Spacer()
        }
        .padding(.horizontal, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func dynamicLineLimit(_ s: String) -> Int {
        min(4, max(2, s.components(separatedBy: "\n").count))
    }
}
