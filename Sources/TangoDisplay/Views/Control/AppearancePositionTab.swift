import SwiftUI
import TangoDisplayCore

/// Per-element horizontal/vertical position offsets for the presentation text, mirroring the
/// album-artwork position controls. A non-zero horizontal offset left-aligns that element so the
/// value measures its left edge; zero keeps it centred. Offsets are shared between the dance display
/// and the cortina "coming up" section, like the fonts and colours.
struct AppearancePositionTab: View {
    @Binding var working: AppearanceProfile
    @EnvironmentObject var appState: AppState
    @State private var selectedGenreID: UUID? = nil

    private var genreEntries: [GenreBackground] {
        let dance = working.genreBackgrounds.filter { !$0.isCortinaEntry }
        let cortina = working.genreBackgrounds.filter { $0.isCortinaEntry }
        return dance + cortina
    }
    private func genreLabel(_ g: GenreBackground) -> String {
        g.isCortinaEntry ? "\(appState.settings.cortinaLabel) (cortina)" : g.genreKey
    }
    private var effectiveGenreID: UUID? { selectedGenreID ?? genreEntries.first?.id }
    private var selectedGenre: GenreBackground? {
        genreEntries.first { $0.id == effectiveGenreID }
    }

    private func saveToGenre() {
        guard let id = effectiveGenreID,
              let idx = working.genreBackgrounds.firstIndex(where: { $0.id == id }) else { return }
        working.genreBackgrounds[idx].positions = working.currentPlacements()
    }
    private func loadFromGenre() {
        guard let id = effectiveGenreID,
              let g = working.genreBackgrounds.first(where: { $0.id == id }),
              let set = g.positions else { return }
        working = working.applyingPositionOverride(set)
    }
    private func clearGenreOverride() {
        guard let id = effectiveGenreID,
              let idx = working.genreBackgrounds.firstIndex(where: { $0.id == id }) else { return }
        working.genreBackgrounds[idx].positions = nil
    }

    var body: some View {
        Form {
            Section {
                if genreEntries.isEmpty {
                    Text("Add genre backgrounds in the Artwork & Motion tab to save genre-specific positions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Picker("Genre", selection: $selectedGenreID) {
                        ForEach(genreEntries) { g in
                            Text(genreLabel(g) + (g.positions != nil ? "  ✓" : "")).tag(Optional(g.id))
                        }
                    }
                    HStack {
                        Button("Load from genre") { loadFromGenre() }
                            .disabled(selectedGenre?.positions == nil)
                        Button("Save to genre") { saveToGenre() }
                        Spacer()
                        Button("Clear override", role: .destructive) { clearGenreOverride() }
                            .disabled(selectedGenre?.positions == nil)
                    }
                }
            } header: {
                Text("Genre-specific positions")
                    .foregroundColor(ControlTheme.accent)
            } footer: {
                Label {
                    Text("Set up the positions below (and artwork in Artwork & Motion), check the preview, then Save to a genre. While that genre plays, these positions and artwork apply; otherwise the profile defaults are used. Load pulls a genre's saved setup back in to edit.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

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

            Section {
                HStack {
                    Text("Horizontal").foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                    Slider(value: $working.albumArtworkOffsetX, in: -100...100)
                    Text(String(format: "%+.0f%%", working.albumArtworkOffsetX)).monospacedDigit().frame(width: 48)
                }
                HStack {
                    Text("Vertical").foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                    Slider(value: $working.albumArtworkOffsetY, in: -100...100)
                    Text(String(format: "%+.0f%%", working.albumArtworkOffsetY)).monospacedDigit().frame(width: 48)
                }
                HStack {
                    Text("Size").foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                    Slider(value: $working.albumArtworkScale, in: 0.1...5.0)
                    Text(String(format: "%.2f×", working.albumArtworkScale)).monospacedDigit().frame(width: 48)
                }
                HStack {
                    Text("Opacity").foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                    Slider(value: $working.albumArtworkOpacity, in: 0...1)
                    Text(String(format: "%.0f%%", working.albumArtworkOpacity * 100)).monospacedDigit().frame(width: 48)
                }
            } header: {
                Text("Album Artwork")
                    .foregroundColor(ControlTheme.accent)
            } footer: {
                Label {
                    Text("Position (percent of resolution) and size of the album artwork. Included when you Save to a genre above. Fade style/intensity stay on the Artwork & Motion tab.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            appState.showElementBoundsInPreview = true
            if selectedGenreID == nil { selectedGenreID = genreEntries.first?.id }
        }
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
