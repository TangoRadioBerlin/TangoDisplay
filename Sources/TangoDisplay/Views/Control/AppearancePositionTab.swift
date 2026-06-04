import SwiftUI
import TangoDisplayCore

/// Per-element horizontal/vertical position offsets for the presentation text, mirroring the
/// album-artwork position controls. A non-zero horizontal offset left-aligns that element so the
/// value measures its left edge; zero keeps it centred. Offsets are shared between the dance display
/// and the cortina "coming up" section, like the fonts and colours.
struct AppearancePositionTab: View {
    @Binding var working: AppearanceProfile
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                offsetRow("Title",  x: $working.titleOffsetX,  y: $working.titleOffsetY,  bw: $working.titleBoxWidth)
                offsetRow("Artist", x: $working.artistOffsetX, y: $working.artistOffsetY, bw: $working.artistBoxWidth)
                offsetRow("Genre",  x: $working.genreOffsetX,  y: $working.genreOffsetY,  bw: $working.genreBoxWidth)
                offsetRow("Year",   x: $working.yearOffsetX,   y: $working.yearOffsetY,   bw: $working.yearBoxWidth)
                offsetRow("Singer", x: $working.singerOffsetX, y: $working.singerOffsetY, bw: $working.singerBoxWidth)
                offsetRow("Track Counter", x: $working.trackCounterOffsetX, y: $working.trackCounterOffsetY, bw: $working.trackCounterBoxWidth)
                offsetRow("Last Tanda Label", x: $working.lastTandaLabelOffsetX, y: $working.lastTandaLabelOffsetY, bw: $working.lastTandaLabelBoxWidth)
            } header: {
                Text("Dance / General")
                    .foregroundColor(ControlTheme.accent)
            } footer: {
                Label {
                    Text("A horizontal offset other than 0 left-aligns that element (offset = distance of its left edge). 0 keeps it centred. Vertical offset only moves the element up/down.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            Section {
                offsetRow("Cortina Label",  x: $working.cortinaLabelOffsetX,  y: $working.cortinaLabelOffsetY,  bw: $working.cortinaLabelBoxWidth)
                offsetRow("Cortina Artist", x: $working.cortinaArtistOffsetX, y: $working.cortinaArtistOffsetY, bw: $working.cortinaArtistBoxWidth)
                offsetRow("Cortina Title",  x: $working.cortinaTitleOffsetX,  y: $working.cortinaTitleOffsetY,  bw: $working.cortinaTitleBoxWidth)
                offsetRow("Next Up Label",  x: $working.nextUpLabelOffsetX,   y: $working.nextUpLabelOffsetY,   bw: $working.nextUpLabelBoxWidth)
            } header: {
                Text("Cortina")
                    .foregroundColor(ControlTheme.accent)
            }
        }
        .formStyle(.grouped)
        .onAppear { appState.showElementBoundsInPreview = true }
        .onDisappear { appState.showElementBoundsInPreview = false }
    }

    @ViewBuilder
    private func offsetRow(_ label: String, x: Binding<Double>, y: Binding<Double>, bw: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .frame(width: 120, alignment: .leading)
                Spacer()
                Button("Reset") {
                    x.wrappedValue = 0
                    y.wrappedValue = 0
                    bw.wrappedValue = 0
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(x.wrappedValue == 0 && y.wrappedValue == 0 && bw.wrappedValue == 0)
            }
            HStack {
                Text("Horizontal")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Slider(value: x, in: -2000...2000)
                Text(String(format: "%+.0f", x.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 48)
            }
            HStack {
                Text("Vertical")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Slider(value: y, in: -2000...2000)
                Text(String(format: "%+.0f", y.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 48)
            }
            HStack {
                Text("Box width")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Slider(value: bw, in: 0...4000)
                Text(bw.wrappedValue == 0 ? "off" : String(format: "%.0f", bw.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 48)
            }
            .opacity(x.wrappedValue != 0 ? 1 : 0.4)
            .help("Only active with a horizontal offset: the text shrinks to fit this width on one line. 0 = off.")
        }
        .padding(.vertical, 2)
    }
}
