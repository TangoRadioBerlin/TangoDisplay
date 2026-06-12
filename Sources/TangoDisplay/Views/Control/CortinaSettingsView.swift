import SwiftUI

struct CortinaSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @State private var newAllowlistGenre = ""
    @State private var newDenylistGenre = ""

    var body: some View {
        Form {
            // Warning if both rules are off
            if !settings.useAllowlist && !settings.useDenylist  {
                Label("Both rules are disabled — nothing will be detected as a cortina.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline)
            }

            Section {
                Toggle("Allowlist rule", isOn: $settings.useAllowlist)
                Text("A track is a cortina if its genre matches one of these genres:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                allowlistEditor()
            } header: {
                Text("Cortina Genres (allowlist)")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                Toggle("Denylist rule", isOn: $settings.useDenylist)
                Text("A track is a cortina if its genre is NOT in this list of dance genres:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                denylistEditor()
            } header: {
                Text("Dance Genres (denylist)")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                Text("When both rules are enabled, a track is a cortina if **either** rule matches.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Empty genre fields are treated as cortinas under the denylist rule.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Notes")
                    .foregroundColor(ControlTheme.accent)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func genreListEditor(
        genres: Binding<[String]>,
        newGenre: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(genres.wrappedValue.indices, id: \.self) { idx in
                HStack {
                    Text(genres.wrappedValue[idx])
                        .font(.system(size: 13))
                    Spacer()
                    Button {
                        genres.wrappedValue.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }

            HStack {
                TextField(placeholder, text: newGenre)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { addGenre(genres: genres, newGenre: newGenre) }

                Button("Add") { addGenre(genres: genres, newGenre: newGenre) }
                    .buttonStyle(.bordered)
                    .disabled(newGenre.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addGenre(genres: Binding<[String]>, newGenre: Binding<String>) {
        let trimmed = newGenre.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !genres.wrappedValue.contains(trimmed) else { return }
        genres.wrappedValue.append(trimmed)
        newGenre.wrappedValue = ""
    }

    private func denylistEditor() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Column 1: Genre
                VStack(alignment: .leading, spacing: 6) {
                    Text("Genre")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(settings.denylistGenres.indices, id: \.self) { idx in
                        Text(settings.denylistGenres[idx])
                            .font(.system(size: 13))
                            .frame(height: 22)
                    }
                }

                // Column 2: Display label — fills available width
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Display label")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(settings.denylistGenres.indices, id: \.self) { idx in
                        let genre = settings.denylistGenres[idx]
                        TextField(text: Binding(
                            get: { settings.denylistLabelOverrides[genre] ?? "" },
                            set: { newValue in
                                let v = newValue.trimmingCharacters(in: .whitespaces)
                                if v.isEmpty {
                                    settings.denylistLabelOverrides.removeValue(forKey: genre)
                                } else {
                                    settings.denylistLabelOverrides[genre] = v
                                }
                            }
                        ), prompt: Text("e.g. Your label").foregroundColor(.secondary)) {
                            EmptyView()
                        }
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Column 3: Controls
                VStack(alignment: .leading, spacing: 6) {
                    Text("").font(.caption) // height spacer matching header row
                    ForEach(settings.denylistGenres.indices, id: \.self) { idx in
                        let genre = settings.denylistGenres[idx]
                        HStack(spacing: 8) {
                            Toggle("Partial match", isOn: Binding(
                                get: { settings.denylistPartialMatchGenres.contains(genre) },
                                set: { enabled in
                                    if enabled {
                                        settings.denylistPartialMatchGenres.insert(genre)
                                    } else {
                                        settings.denylistPartialMatchGenres.remove(genre)
                                    }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .fixedSize()
                            .help("Also matches genres containing \"\(genre)\" anywhere (e.g. \"\(genre) Instrumental\", \"Alt \(genre)\")")
                            Button {
                                settings.denylistGenres.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(height: 22)
                    }
                }
            }
            .padding(.horizontal, 6)

            HStack {
                TextField("e.g. Tango", text: $newDenylistGenre)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { addDenylistGenre() }
                Button("Add") { addDenylistGenre() }
                    .buttonStyle(.bordered)
                    .disabled(newDenylistGenre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func allowlistEditor() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(settings.allowlistGenres.indices, id: \.self) { idx in
                let genre = settings.allowlistGenres[idx]
                HStack(spacing: 8) {
                    Text(genre).frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("Partial match", isOn: Binding(
                        get: { settings.allowlistPartialMatchGenres.contains(genre) },
                        set: { enabled in
                            if enabled {
                                settings.allowlistPartialMatchGenres.insert(genre)
                            } else {
                                settings.allowlistPartialMatchGenres.remove(genre)
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .fixedSize()
                    .help("Also matches genres containing \"\(genre)\" at a word boundary (e.g. \"\(genre) Instrumental\", \"Alt \(genre)\")")
                    Button {
                        settings.allowlistGenres.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 22)
            }
            HStack {
                TextField("e.g. Cortina", text: $newAllowlistGenre)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { addAllowlistGenre() }
                Button("Add") { addAllowlistGenre() }
                    .buttonStyle(.bordered)
                    .disabled(newAllowlistGenre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addAllowlistGenre() {
        let trimmed = newAllowlistGenre.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !settings.allowlistGenres.contains(trimmed) else { return }
        settings.allowlistGenres.append(trimmed)
        newAllowlistGenre = ""
    }

    private func addDenylistGenre() {
        let trimmed = newDenylistGenre.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !settings.denylistGenres.contains(trimmed) else { return }
        settings.denylistGenres.append(trimmed)
        settings.denylistPartialMatchGenres.insert(trimmed)  // checked by default
        newDenylistGenre = ""
    }
}
