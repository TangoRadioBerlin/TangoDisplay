import SwiftUI
import TangoDisplayCore

/// Per-genre-background position editor. Lets the user override the profile's element positions for
/// the time a given genre is playing. nil = use profile defaults.
struct GenrePositionsSheet: View {
    @Binding var genre: GenreBackground
    let genreLabel: String
    let defaults: PositionSet
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Positions — \(genreLabel)")
                    .font(.headline)
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()

            if genre.positions == nil {
                VStack(spacing: 12) {
                    Text("This genre uses the profile's default positions.")
                        .foregroundColor(.secondary)
                    Button("Customize positions for this genre") {
                        genre.positions = defaults
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(AppearanceProfile.positionElementKeys, id: \.self) { key in
                            row(key)
                            Divider()
                        }
                        artworkRow()
                    }
                    .padding()
                }
                HStack {
                    Button("Reset to profile defaults", role: .destructive) {
                        genre.positions = nil
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 460, height: 560)
    }

    private var artworkBinding: Binding<ArtworkPlacement> {
        Binding(
            get: { genre.positions?.artwork ?? ArtworkPlacement() },
            set: { genre.positions?.artwork = $0 }
        )
    }

    @ViewBuilder
    private func artworkRow() -> some View {
        let a = artworkBinding
        VStack(spacing: 2) {
            Text("Album Artwork")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 12, weight: .semibold))
            HStack {
                Text("X").foregroundColor(.secondary).frame(width: 16)
                Slider(value: a.offsetX, in: -2000...2000)
                Text(String(format: "%+.0f", a.wrappedValue.offsetX)).monospacedDigit().frame(width: 48)
            }
            HStack {
                Text("Y").foregroundColor(.secondary).frame(width: 16)
                Slider(value: a.offsetY, in: -2000...2000)
                Text(String(format: "%+.0f", a.wrappedValue.offsetY)).monospacedDigit().frame(width: 48)
            }
            HStack {
                Text("Size").foregroundColor(.secondary).frame(width: 32, alignment: .leading)
                Slider(value: a.scale, in: 0.1...5.0)
                Text(String(format: "%.2f×", a.wrappedValue.scale)).monospacedDigit().frame(width: 48)
            }
            HStack {
                Text("Opacity").foregroundColor(.secondary).frame(width: 48, alignment: .leading)
                Slider(value: a.opacity, in: 0...1)
                Text(String(format: "%.0f%%", a.wrappedValue.opacity * 100)).monospacedDigit().frame(width: 48)
            }
        }
        .padding(.vertical, 2)
    }

    private func placementBinding(_ key: String) -> Binding<ElementPlacement> {
        Binding(
            get: { genre.positions?.placements[key] ?? ElementPlacement() },
            set: { genre.positions?.placements[key] = $0 }
        )
    }

    @ViewBuilder
    private func row(_ key: String) -> some View {
        let p = placementBinding(key)
        VStack(spacing: 2) {
            Text(AppearanceProfile.positionElementDisplayName(key))
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 12, weight: .semibold))
            HStack {
                Text("X").foregroundColor(.secondary).frame(width: 16)
                Slider(value: p.offsetX, in: -100...100)
                Text(String(format: "%+.0f%%", p.wrappedValue.offsetX)).monospacedDigit().frame(width: 44)
            }
            HStack {
                Text("Y").foregroundColor(.secondary).frame(width: 16)
                Slider(value: p.offsetY, in: -100...100)
                Text(String(format: "%+.0f%%", p.wrappedValue.offsetY)).monospacedDigit().frame(width: 44)
            }
            HStack {
                Text("Box").foregroundColor(.secondary).frame(width: 32, alignment: .leading)
                Slider(value: p.boxWidth, in: 0...100)
                Text(p.wrappedValue.boxWidth == 0 ? "off" : String(format: "%.0f%%", p.wrappedValue.boxWidth))
                    .monospacedDigit().frame(width: 44)
                Picker("", selection: p.hAlign) {
                    ForEach(TextHAlignment.allCases, id: \.self) { a in Text(a.displayName).tag(a) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
        }
        .padding(.vertical, 2)
    }
}
