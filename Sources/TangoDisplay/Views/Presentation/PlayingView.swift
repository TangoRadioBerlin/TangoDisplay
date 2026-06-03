import SwiftUI
import TangoDisplayCore

struct PlayingView: View {
    let state: DisplayState
    let profile: AppearanceProfile
    let isLastTandaActive: Bool
    @ObservedObject var settings: AppSettings

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
                            .positioned(offsetX: profile.genreOffsetX, offsetY: profile.genreOffsetY)
                    }
                case .artist:
                    if profile.showArtistDance, let artist = state.currentTrack?.artist, !artist.isEmpty {
                        let displayArtist = settings.transform(artist, for: .artist)
                        Text(displayArtist)
                            .font(profile.artistFont)
                            .foregroundColor(profile.artistSwiftUIColor)
                            .lineLimit(Self.dynamicLineLimit(displayArtist))
                            .minimumScaleFactor(0.5)
                            .positioned(offsetX: profile.artistOffsetX, offsetY: profile.artistOffsetY)
                    }
                case .year:
                    if profile.showYearDance, let year = state.currentTrack?.year {
                        let displayYear = settings.transform(String(year), for: .year)
                        if !displayYear.isEmpty {
                            Text(displayYear)
                                .font(profile.yearFont)
                                .foregroundColor(profile.yearSwiftUIColor)
                                .positioned(offsetX: profile.yearOffsetX, offsetY: profile.yearOffsetY)
                        }
                    }
                case .title:
                    if profile.showTitleDance, let title = state.currentTrack?.title, !title.isEmpty {
                        let displayTitle = settings.transform(title, for: .title)
                        Text(displayTitle)
                            .font(profile.titleFont)
                            .foregroundColor(profile.titleSwiftUIColor)
                            .lineLimit(Self.dynamicLineLimit(displayTitle))
                            .minimumScaleFactor(0.5)
                            .positioned(offsetX: profile.titleOffsetX, offsetY: profile.titleOffsetY)
                    }
                case .singer:
                    if profile.showSingerDance,
                       let rawSinger = state.currentTrack.flatMap({ profile.singerValue(from: $0) }),
                       !rawSinger.isEmpty {
                        let singerField: TrackInfoField = {
                            switch profile.singerSource {
                            case .albumArtist: return .albumArtist
                            case .comments:    return .comments
                            case .grouping:    return .grouping
                            }
                        }()
                        let singer = settings.transform(rawSinger, for: singerField)
                        if !singer.isEmpty {
                            Text(singer)
                                .font(profile.singerFont)
                                .foregroundColor(profile.singerSwiftUIColor)
                                .lineLimit(Self.dynamicLineLimit(singer))
                                .minimumScaleFactor(0.5)
                                .positioned(offsetX: profile.singerOffsetX, offsetY: profile.singerOffsetY)
                        }
                    }
                case .lastTandaLabel:
                    if profile.showLastTandaLabel, isLastTandaActive, !settings.lastTandaLabel.isEmpty {
                        Text(settings.lastTandaLabel.uppercased())
                            .font(profile.lastTandaLabelFont)
                            .foregroundColor(profile.lastTandaLabelSwiftUIColor)
                            .positioned(offsetX: profile.lastTandaLabelOffsetX, offsetY: profile.lastTandaLabelOffsetY)
                    }
                case .trackCounter:
                    if settings.showTrackCounter,
                       settings.trackCounterPosition == .centre,
                       let pos = state.tandaPosition {
                        Text(pos.label)
                            .font(profile.trackCounterFont)
                            .foregroundColor(profile.trackCounterSwiftUIColor)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                            .positioned(offsetX: profile.trackCounterOffsetX, offsetY: profile.trackCounterOffsetY)
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
