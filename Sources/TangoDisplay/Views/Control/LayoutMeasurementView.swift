import SwiftUI
import TangoDisplayCore

/// Invisible full-resolution (1920×1080) rendering of the presentation views with
/// sample content, used to measure each element's flow position (pre-offset) for
/// the flow→absolute layout conversion on the Position tab.
///
/// PlayingView reports the dance/general element keys and CortinaView only the
/// cortina-exclusive ones (see the `measureKey` arguments in those views), so both
/// can render into one preference dictionary without colliding.
struct LayoutMeasurementView: View {
    let profile: AppearanceProfile
    @ObservedObject var settings: AppSettings
    let onMeasure: ([String: ElementCenter]) -> Void

    static let measurementSize = CGSize(width: 1920, height: 1080)

    private static let danceState = DisplayState(
        mode: .playing,
        currentTrack: Track(title: "Sample Title", artist: "Sample Artist", genre: "Tango",
                            persistentID: "measure-sample", year: 1947,
                            comment: "Sample Singer", albumArtist: "Sample Singer",
                            grouping: "Sample Singer"),
        tandaPosition: TandaPosition(current: 2, total: 4)
    )

    private static let cortinaState = DisplayState(
        mode: .cortina,
        currentTrack: Track(title: "Cortina Title", artist: "Cortina Artist", genre: "Cortina",
                            persistentID: "measure-cortina"),
        nextTrack: Track(title: "Next Title", artist: "Next Artist", genre: "Tango",
                         persistentID: "measure-next")
    )

    private static let lastPlayed = Track(
        title: "Previous Title", artist: "Previous Artist", genre: "Tango",
        persistentID: "measure-last")

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlayingView(state: Self.danceState, profile: profile, isLastTandaActive: true,
                        settings: settings, lastPlayedTrack: Self.lastPlayed,
                        containerSize: Self.measurementSize)
            CortinaView(state: Self.cortinaState, profile: profile, isLastTandaActive: false,
                        settings: settings, lastPlayedTrack: nil,
                        containerSize: Self.measurementSize)
        }
        .frame(width: Self.measurementSize.width, height: Self.measurementSize.height)
        .overlayPreferenceValue(ElementFramesPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                let centers = anchors.mapValues { anchor -> ElementCenter in
                    let rect = proxy[anchor]
                    return ElementCenter(x: rect.midX, y: rect.midY)
                }
                Color.clear
                    .onAppear { DispatchQueue.main.async { onMeasure(centers) } }
                    .onChange(of: centers) { onMeasure($0) }
            }
        }
    }
}
