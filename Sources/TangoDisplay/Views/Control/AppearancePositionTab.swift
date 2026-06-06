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
                offsetRow("Title",  x: $working.titleOffsetX,  y: $working.titleOffsetY,  bw: $working.titleBoxWidth,  align: $working.titleHAlign)
                offsetRow("Artist", x: $working.artistOffsetX, y: $working.artistOffsetY, bw: $working.artistBoxWidth, align: $working.artistHAlign)
                offsetRow("Genre",  x: $working.genreOffsetX,  y: $working.genreOffsetY,  bw: $working.genreBoxWidth,  align: $working.genreHAlign)
                offsetRow("Year",   x: $working.yearOffsetX,   y: $working.yearOffsetY,   bw: $working.yearBoxWidth,   align: $working.yearHAlign)
                offsetRow("Singer", x: $working.singerOffsetX, y: $working.singerOffsetY, bw: $working.singerBoxWidth, align: $working.singerHAlign)
                offsetRow("Track Counter", x: $working.trackCounterOffsetX, y: $working.trackCounterOffsetY, bw: $working.trackCounterBoxWidth, align: $working.trackCounterHAlign)
                offsetRow("Last Tanda Label", x: $working.lastTandaLabelOffsetX, y: $working.lastTandaLabelOffsetY, bw: $working.lastTandaLabelBoxWidth, align: $working.lastTandaLabelHAlign)
                offsetRow("Last Played", x: $working.lastPlayedOffsetX, y: $working.lastPlayedOffsetY, bw: $working.lastPlayedBoxWidth, align: $working.lastPlayedHAlign)
            } header: {
                Text("Dance / General")
                    .foregroundColor(ControlTheme.accent)
            } footer: {
                Label {
                    Text("Offsets are percentages of the screen resolution (−100…100 %, 0 = unchanged) so the layout scales across displays. Box width is a percentage of the screen width (0 = full width). Alignment positions the text left/centre/right within its box.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            Section {
                offsetRow("Cortina Label",  x: $working.cortinaLabelOffsetX,  y: $working.cortinaLabelOffsetY,  bw: $working.cortinaLabelBoxWidth,  align: $working.cortinaLabelHAlign)
                offsetRow("Cortina Artist", x: $working.cortinaArtistOffsetX, y: $working.cortinaArtistOffsetY, bw: $working.cortinaArtistBoxWidth, align: $working.cortinaArtistHAlign)
                offsetRow("Cortina Title",  x: $working.cortinaTitleOffsetX,  y: $working.cortinaTitleOffsetY,  bw: $working.cortinaTitleBoxWidth,  align: $working.cortinaTitleHAlign)
                offsetRow("Next Up Label",  x: $working.nextUpLabelOffsetX,   y: $working.nextUpLabelOffsetY,   bw: $working.nextUpLabelBoxWidth,   align: $working.nextUpLabelHAlign)
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
    private func offsetRow(_ label: String, x: Binding<Double>, y: Binding<Double>,
                           bw: Binding<Double>, align: Binding<TextHAlignment>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .frame(width: 120, alignment: .leading)
                Spacer()
                Button("Reset") {
                    x.wrappedValue = 0
                    y.wrappedValue = 0
                    bw.wrappedValue = 0
                    align.wrappedValue = .center
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(x.wrappedValue == 0 && y.wrappedValue == 0
                          && bw.wrappedValue == 0 && align.wrappedValue == .center)
            }
            HStack {
                Text("Horizontal")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Slider(value: x, in: -100...100)
                Text(String(format: "%+.0f%%", x.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 48)
            }
            HStack {
                Text("Vertical")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Slider(value: y, in: -100...100)
                Text(String(format: "%+.0f%%", y.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 48)
            }
            HStack {
                Text("Box width")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Slider(value: bw, in: 0...100)
                Text(bw.wrappedValue == 0 ? "off" : String(format: "%.0f%%", bw.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 48)
            }
            HStack {
                Text("Alignment")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: align) {
                    ForEach(TextHAlignment.allCases, id: \.self) { a in
                        Text(a.displayName).tag(a)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
        .padding(.vertical, 2)
    }
}
