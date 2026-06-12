import SwiftUI
import TangoDisplayCore

struct PlayingView: View {
    let state: DisplayState
    let profile: AppearanceProfile
    let isLastTandaActive: Bool
    @ObservedObject var settings: AppSettings
    var lastPlayedTrack: Track? = nil
    var showBounds: Bool = false
    var containerSize: CGSize = .zero

    var body: some View {
        Group {
            if profile.layoutMode == .absolute {
                // Each element anchors at screen centre + its own offset, so an empty
                // field never shifts its neighbours.
                ZStack {
                    ForEach(profile.danceItemOrder, id: \.self) { item in
                        itemView(item)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    ForEach(profile.danceItemOrder, id: \.self) { item in
                        itemView(item)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func itemView(_ item: DisplayTextItem) -> some View {
        switch item {
        case .genre:
            if profile.showGenreDance, let genre = state.currentTrack?.genre, !genre.isEmpty {
                Text(profile.genreTextCase.apply(settings.displayLabel(for: genre)))
                    .font(profile.genreFont(containerSize.height))
                    .foregroundColor(profile.genreSwiftUIColor)
                    .positioned(offsetX: profile.genreOffsetX, offsetY: profile.genreOffsetY,
                                boxWidth: profile.genreBoxWidth, hAlign: profile.genreHAlign,
                                showBounds: showBounds, containerSize: containerSize, measureKey: "genre")
            }
        case .artist:
            if profile.showArtistDance, let track = state.currentTrack {
                let displayArtist = settings.effectiveValue(of: .artist, from: track)
                if !displayArtist.isEmpty {
                    Text(displayArtist)
                        .font(profile.artistFont(containerSize.height))
                        .foregroundColor(profile.artistSwiftUIColor)
                        .positioned(offsetX: profile.artistOffsetX, offsetY: profile.artistOffsetY,
                                    boxWidth: profile.artistBoxWidth, hAlign: profile.artistHAlign,
                                    lineLimit: Self.dynamicLineLimit(displayArtist), autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize, measureKey: "artist")
                }
            }
        case .year:
            if profile.showYearDance, let track = state.currentTrack {
                let rawYear = settings.effectiveValue(of: .year, from: track)
                let displayYear = (!rawYear.isEmpty && profile.yearInParentheses) ? "(\(rawYear))" : rawYear
                if !displayYear.isEmpty {
                    Text(displayYear)
                        .font(profile.yearFont(containerSize.height))
                        .foregroundColor(profile.yearSwiftUIColor)
                        .positioned(offsetX: profile.yearOffsetX, offsetY: profile.yearOffsetY,
                                    boxWidth: profile.yearBoxWidth, hAlign: profile.yearHAlign,
                                    showBounds: showBounds, containerSize: containerSize, measureKey: "year")
                }
            }
        case .title:
            if profile.showTitleDance, let track = state.currentTrack {
                let displayTitle = settings.effectiveValue(of: .title, from: track)
                if !displayTitle.isEmpty {
                    Text(displayTitle)
                        .font(profile.titleFont(containerSize.height))
                        .foregroundColor(profile.titleSwiftUIColor)
                        .positioned(offsetX: profile.titleOffsetX, offsetY: profile.titleOffsetY,
                                    boxWidth: profile.titleBoxWidth, hAlign: profile.titleHAlign,
                                    lineLimit: Self.dynamicLineLimit(displayTitle), autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize, measureKey: "title")
                }
            }
        case .singer:
            if profile.showSingerDance, let track = state.currentTrack {
                let singer = settings.effectiveValue(of: profile.singerSource.trackInfoField, from: track)
                if !singer.isEmpty {
                    Text(singer)
                        .font(profile.singerFont(containerSize.height))
                        .foregroundColor(profile.singerSwiftUIColor)
                        .positioned(offsetX: profile.singerOffsetX, offsetY: profile.singerOffsetY,
                                    boxWidth: profile.singerBoxWidth, hAlign: profile.singerHAlign,
                                    lineLimit: Self.dynamicLineLimit(singer), autoShrink: true,
                                    showBounds: showBounds, containerSize: containerSize, measureKey: "singer")
                }
            }
        case .lastTandaLabel:
            if profile.showLastTandaLabel, isLastTandaActive, !settings.lastTandaLabel.isEmpty {
                Text(settings.lastTandaLabel.uppercased())
                    .font(profile.lastTandaLabelFont(containerSize.height))
                    .foregroundColor(profile.lastTandaLabelSwiftUIColor)
                    .positioned(offsetX: profile.lastTandaLabelOffsetX, offsetY: profile.lastTandaLabelOffsetY,
                                boxWidth: profile.lastTandaLabelBoxWidth, hAlign: profile.lastTandaLabelHAlign,
                                showBounds: showBounds, containerSize: containerSize, measureKey: "lastTandaLabel")
            }
        case .trackCounter:
            if settings.showTrackCounter,
               settings.trackCounterPosition == .centre,
               let pos = state.tandaPosition {
                Text(pos.label)
                    .font(profile.trackCounterFont(containerSize.height))
                    .foregroundColor(profile.trackCounterSwiftUIColor)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                    .positioned(offsetX: profile.trackCounterOffsetX, offsetY: profile.trackCounterOffsetY,
                                boxWidth: profile.trackCounterBoxWidth, hAlign: profile.trackCounterHAlign,
                                showBounds: showBounds, containerSize: containerSize, measureKey: "trackCounter")
            }
        case .lastPlayed:
            if profile.showLastPlayedDance, let lp = lastPlayedTrack {
                let lpText = settings.lastPlayedPrefix + settings.effectiveValue(of: .title, from: lp)
                Text(lpText)
                    .font(profile.lastPlayedFont(containerSize.height))
                    .foregroundColor(profile.lastPlayedSwiftUIColor)
                    .positioned(offsetX: profile.lastPlayedOffsetX, offsetY: profile.lastPlayedOffsetY,
                                boxWidth: profile.lastPlayedBoxWidth, hAlign: profile.lastPlayedHAlign,
                                lineLimit: 2, autoShrink: true,
                                showBounds: showBounds, containerSize: containerSize, measureKey: "lastPlayed")
            }
        case .tdjName:
            if settings.showTdjName,
               settings.tdjNamePosition == .centre,
               !settings.tdjName.isEmpty,
               settings.tdjNameVisibility.isVisible(in: .playing) {
                Text(settings.tdjName)
                    .font(profile.tdjNameFont(containerSize.height))
                    .foregroundColor(profile.tdjNameSwiftUIColor)
                    .positioned(offsetX: profile.tdjNameOffsetX, offsetY: profile.tdjNameOffsetY,
                                boxWidth: profile.tdjNameBoxWidth, hAlign: profile.tdjNameHAlign,
                                showBounds: showBounds, containerSize: containerSize, measureKey: "tdjName")
            }
        case .cortinaLabel, .cortinaArtist, .cortinaTitle, .nextUpLabel:
            EmptyView()
        }
    }

    static func dynamicLineLimit(_ s: String) -> Int {
        min(4, max(2, s.components(separatedBy: "\n").count))
    }
}
