import SwiftUI
import TangoDisplayCore

/// Per-element position editor. The sliders edit **the scene currently selected in the preview**
/// (`appState.previewScene`): "Dance (default)" edits the profile's base offsets, a genre or the
/// cortina edits that scene's sparse position override (`GenreBackground.positions`). Only edited
/// elements go into the override; the rest inherit the dance base. This keeps editing WYSIWYG with
/// the preview and the real presentation screen, which both apply the same override.
struct AppearancePositionTab: View {
    @Binding var working: AppearanceProfile
    @EnvironmentObject var appState: AppState
    @State private var measuredCenters: [String: ElementCenter] = [:]

    // MARK: - Scene resolution

    private var sceneLabel: String {
        switch appState.previewScene {
        case .dance:        return "Dance (default)"
        case .genre(let g): return g
        case .cortina:      return appState.settings.cortinaLabel
        }
    }

    private var isDanceScene: Bool {
        if case .dance = appState.previewScene { return true }
        return false
    }

    /// Index of the GenreBackground entry backing the selected non-dance scene, if it exists.
    private var sceneOverrideIndex: Int? {
        switch appState.previewScene {
        case .dance: return nil
        case .genre(let g):
            return working.genreBackgrounds.firstIndex { !$0.isCortinaEntry && $0.genreKey == g }
        case .cortina:
            return working.genreBackgrounds.firstIndex { $0.isCortinaEntry }
        }
    }

    private var sceneHasOverride: Bool {
        guard let idx = sceneOverrideIndex else { return false }
        return working.genreBackgrounds[idx].positions != nil
    }

    /// Ensures the backing GenreBackground entry for the selected scene exists (creating a cortina
    /// sentinel / genre entry on first edit) and returns its index. nil for the dance scene.
    private func ensureSceneEntryIndex() -> Int? {
        switch appState.previewScene {
        case .dance:
            return nil
        case .genre(let g):
            if let i = working.genreBackgrounds.firstIndex(where: { !$0.isCortinaEntry && $0.genreKey == g }) {
                return i
            }
            working.genreBackgrounds.append(GenreBackground(genreKey: g))
            return working.genreBackgrounds.count - 1
        case .cortina:
            if let i = working.genreBackgrounds.firstIndex(where: { $0.isCortinaEntry }) { return i }
            working.genreBackgrounds.append(GenreBackground(genreKey: ""))
            return working.genreBackgrounds.count - 1
        }
    }

    // MARK: - Scene-aware bindings

    /// Reads/writes one element's placement for the selected scene. Genre/cortina scenes read the
    /// override and fall back to the base when the element hasn't been overridden yet; writes create
    /// a sparse override entry. SwiftUI's dynamic-member lookup turns this into per-axis bindings.
    private func placementBinding(_ key: String) -> Binding<ElementPlacement> {
        Binding(
            get: {
                if let idx = sceneOverrideIndex,
                   let p = working.genreBackgrounds[idx].positions?.placements[key] {
                    return p
                }
                return working.placement(forKey: key)
            },
            set: { newValue in
                guard let idx = ensureSceneEntryIndex() else {
                    working.setPlacement(newValue, forKey: key)   // dance scene → base fields
                    return
                }
                var set = working.genreBackgrounds[idx].positions ?? PositionSet()
                set.placements[key] = newValue
                working.genreBackgrounds[idx].positions = set
            }
        )
    }

    /// Album-artwork placement for the selected scene (offset/scale/opacity). Edge-fade and fade
    /// style are profile-global and stay bound to the base fields.
    private func artworkBinding() -> Binding<ArtworkPlacement> {
        Binding(
            get: {
                if let idx = sceneOverrideIndex,
                   let a = working.genreBackgrounds[idx].positions?.artwork {
                    return a
                }
                return working.currentArtworkPlacement()
            },
            set: { newValue in
                guard let idx = ensureSceneEntryIndex() else {
                    working.albumArtworkOffsetX = newValue.offsetX
                    working.albumArtworkOffsetY = newValue.offsetY
                    working.albumArtworkScale = newValue.scale
                    working.albumArtworkOpacity = newValue.opacity
                    return
                }
                var set = working.genreBackgrounds[idx].positions ?? PositionSet()
                set.artwork = newValue
                working.genreBackgrounds[idx].positions = set
            }
        )
    }

    private func clearSceneOverride() {
        guard let idx = sceneOverrideIndex else { return }
        working.genreBackgrounds[idx].positions = nil
    }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $working.layoutMode) {
                    ForEach(LayoutMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                if working.layoutMode == .flow {
                    Button("Convert to absolute layout (keep current look)") {
                        working = working.convertedToAbsoluteLayout(
                            measuredCenters: measuredCenters,
                            containerWidth: LayoutMeasurementView.measurementSize.width,
                            containerHeight: LayoutMeasurementView.measurementSize.height)
                    }
                    .disabled(measuredCenters.isEmpty)
                }
            } header: {
                Text("Layout mode")
                    .foregroundColor(ControlTheme.accent)
            } footer: {
                Label {
                    Text(working.layoutMode == .flow
                         ? "Stacked: elements flow vertically, so a track without e.g. a singer shifts the others. Convert keeps the current look but anchors every element independently — empty fields then never move their neighbours."
                         : "Absolute: every element is anchored at screen centre plus its offsets; empty fields never shift the others. Switching back to Stacked keeps the converted offsets, so positions will jump — usually you want to stay absolute.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            Section {
                HStack {
                    Text("Editing scene:")
                        .foregroundColor(.secondary)
                    Text(sceneLabel).fontWeight(.semibold)
                    Spacer()
                    if !isDanceScene {
                        Button("Clear override", role: .destructive) { clearSceneOverride() }
                            .controlSize(.small)
                            .disabled(!sceneHasOverride)
                    }
                }
                if !isDanceScene && !working.genreBackgroundsEnabled {
                    Label("Per-genre positions only take effect with Genre Backgrounds enabled (Artwork & Motion tab).",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } header: {
                Text("Scene")
                    .foregroundColor(ControlTheme.accent)
            } footer: {
                Label {
                    Text("Pick the scene to position with the **Scene** menu above the preview. The sliders below change that scene: \"Dance (default)\" sets the base layout; a genre or the cortina overrides only the elements you touch (others inherit Dance). Clear override makes the scene inherit Dance again.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            Section {
                offsetRow("Title", key: "title")
                offsetRow("Artist", key: "artist")
                offsetRow("Genre", key: "genre")
                offsetRow("Year", key: "year")
                offsetRow("Singer", key: "singer")
                offsetRow("Track Counter", key: "trackCounter")
                offsetRow("Last Tanda Label", key: "lastTandaLabel")
                offsetRow("Last Played", key: "lastPlayed")
                offsetRow("TDJ Name", key: "tdjName")
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
                offsetRow("Cortina Label", key: "cortinaLabel")
                offsetRow("Cortina Artist", key: "cortinaArtist")
                offsetRow("Cortina Title", key: "cortinaTitle")
                offsetRow("Next Up Label", key: "nextUpLabel")
            } header: {
                Text("Cortina")
                    .foregroundColor(ControlTheme.accent)
            }

            artworkSection
        }
        .formStyle(.grouped)
        .background(measurementHost)
        .onAppear {
            appState.showElementBoundsInPreview = true
            validatePreviewScene()
        }
        .onDisappear { appState.showElementBoundsInPreview = false }
    }

    // MARK: - Album artwork (scene-aware position/scale/opacity; global fade)

    @ViewBuilder
    private var artworkSection: some View {
        let art = artworkBinding()
        Section {
            Toggle("Show artwork on dance tracks", isOn: $working.showArtworkDance)
            if working.showArtworkDance || working.showArtworkCortina {
                artworkSlider("Horizontal", value: art.offsetX, range: -100...100, format: "%+.0f%%")
                artworkSlider("Vertical", value: art.offsetY, range: -100...100, format: "%+.0f%%")
                artworkSlider("Size", value: art.scale, range: 0.1...5.0, format: "%.2f×")
                artworkSlider("Opacity", value: art.opacity, range: 0...1, format: "%.0f%%", percent: true)
                artworkSlider("Edge Fade", value: $working.albumArtworkEdgeFade, range: 0...1,
                              format: "%.0f%%", percent: true)
                HStack {
                    Text("Fade Style").foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                    Picker("", selection: $working.albumArtworkFadeStyle) {
                        ForEach(AlbumArtFadeStyle.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
        } header: {
            Text("Album Artwork")
                .foregroundColor(ControlTheme.accent)
        } footer: {
            Label {
                Text("Position, size and opacity follow the selected scene; edge fade and style are profile-wide. A placeholder shows the artwork box in the preview while this tab is open.")
            } icon: {
                Image(systemName: "info.circle")
            }
        }
    }

    private func artworkSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
                               format: String, percent: Bool = false) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, percent ? value.wrappedValue * 100 : value.wrappedValue))
                .monospacedDigit().frame(width: 48)
        }
    }

    /// Invisible full-size flow rendering used to seed the flow→absolute conversion.
    /// Mounted only while the profile is still in flow mode.
    @ViewBuilder
    private var measurementHost: some View {
        if working.layoutMode == .flow {
            LayoutMeasurementView(profile: working, settings: appState.settings) {
                measuredCenters = $0
            }
            .fixedSize()
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .frame(width: 0, height: 0)
            .clipped()
        }
    }

    /// If the selected scene points at a genre that no longer exists, fall back to Dance.
    private func validatePreviewScene() {
        if case .genre(let g) = appState.previewScene,
           !working.genreBackgrounds.contains(where: { !$0.isCortinaEntry && $0.genreKey == g }) {
            appState.previewScene = .dance
        }
    }

    @ViewBuilder
    private func offsetRow(_ label: String, key: String) -> some View {
        let p = placementBinding(key)
        offsetRow(label, x: p.offsetX, y: p.offsetY, bw: p.boxWidth, align: p.hAlign)
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
