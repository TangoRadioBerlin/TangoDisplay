import SwiftUI
import TangoDisplayCore

/// Per-element horizontal/vertical position offsets for the presentation text, mirroring the
/// album-artwork position controls. A non-zero horizontal offset left-aligns that element so the
/// value measures its left edge; zero keeps it centred. Offsets are shared between the dance display
/// and the cortina "coming up" section, like the fonts and colours.
struct AppearancePositionTab: View {
    @Binding var working: AppearanceProfile

    var body: some View {
        Form {
            Section {
                offsetRow("Title",        x: $working.titleOffsetX,        y: $working.titleOffsetY)
                offsetRow("Artist",       x: $working.artistOffsetX,       y: $working.artistOffsetY)
                offsetRow("Genre",        x: $working.genreOffsetX,        y: $working.genreOffsetY)
                offsetRow("Year",         x: $working.yearOffsetX,         y: $working.yearOffsetY)
                offsetRow("Singer",       x: $working.singerOffsetX,       y: $working.singerOffsetY)
                offsetRow("Track Counter", x: $working.trackCounterOffsetX, y: $working.trackCounterOffsetY)
                offsetRow("Last Tanda Label", x: $working.lastTandaLabelOffsetX, y: $working.lastTandaLabelOffsetY)
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
                offsetRow("Cortina Label",  x: $working.cortinaLabelOffsetX,  y: $working.cortinaLabelOffsetY)
                offsetRow("Cortina Artist", x: $working.cortinaArtistOffsetX, y: $working.cortinaArtistOffsetY)
                offsetRow("Cortina Title",  x: $working.cortinaTitleOffsetX,  y: $working.cortinaTitleOffsetY)
                offsetRow("Next Up Label",  x: $working.nextUpLabelOffsetX,   y: $working.nextUpLabelOffsetY)
            } header: {
                Text("Cortina")
                    .foregroundColor(ControlTheme.accent)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func offsetRow(_ label: String, x: Binding<Double>, y: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .frame(width: 120, alignment: .leading)
                Spacer()
                Button("Reset") {
                    x.wrappedValue = 0
                    y.wrappedValue = 0
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(x.wrappedValue == 0 && y.wrappedValue == 0)
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
        }
        .padding(.vertical, 2)
    }
}
