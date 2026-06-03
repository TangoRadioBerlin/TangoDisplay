import AVFoundation
import SwiftUI
import TangoDisplayCore

// MARK: - Settings section (embedded in PlayerSettingsView)

struct AudioUnitPluginSettingsSection: View {
    @ObservedObject var player: LocalPlayerSource
    @EnvironmentObject var settings: AppSettings
    @State private var showPickerForSlot: UUID? = nil
    @State private var showPickerForNewSlot = false
    @State private var showReplacePickerForSlot: UUID? = nil

    var body: some View {
        Group {
            Toggle("Enable Audio Unit Plugins", isOn: Binding(
                get: { settings.audioUnitPluginEnabled },
                set: { enabled in
                    if enabled { player.enableAudioUnitPlugin() }
                    else       { player.disableAudioUnitPlugin() }
                }
            ))

            Toggle("Bypass entire chain", isOn: Binding(
                get: { settings.audioUnitPluginBypassed },
                set: { player.bypassAudioUnitPlugin($0) }
            ))
            .disabled(!settings.audioUnitPluginEnabled || settings.audioUnitPluginChain.isEmpty)

            if settings.audioUnitPluginChain.isEmpty {
                Text("No plugins added yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(settings.audioUnitPluginChain.enumerated()), id: \.element.id) { index, slot in
                    AudioUnitChainSlotRow(
                        player: player,
                        slot: slot,
                        index: index,
                        chainCount: settings.audioUnitPluginChain.count,
                        onReplace: { showReplacePickerForSlot = slot.id }
                    )
                    Divider()
                }
            }

            HStack {
                Button {
                    showPickerForNewSlot = true
                } label: {
                    Label("Add Plugin", systemImage: "plus.circle")
                }
                .disabled(settings.audioUnitPluginChain.count >= AudioUnitChainSlot.maxSlots)

                if settings.audioUnitPluginChain.count >= AudioUnitChainSlot.maxSlots {
                    Text("Maximum of \(AudioUnitChainSlot.maxSlots) plugins.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            LabeledContent("Status") {
                Text(player.audioUnitPluginStatus.displayText)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text("Third-party Audio Units run inside TangoDisplay at your own risk. An unstable plugin may interrupt playback.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showPickerForNewSlot) {
            AudioUnitPluginPickerSheet { selection in
                _ = player.addPluginSlot(selection)
                showPickerForNewSlot = false
            }
        }
        .sheet(isPresented: Binding(
            get: { showReplacePickerForSlot != nil },
            set: { if !$0 { showReplacePickerForSlot = nil } })
        ) {
            AudioUnitPluginPickerSheet { selection in
                if let slotId = showReplacePickerForSlot {
                    player.replacePluginSlot(id: slotId, with: selection)
                }
                showReplacePickerForSlot = nil
            }
        }
    }
}

private struct AudioUnitChainSlotRow: View {
    @ObservedObject var player: LocalPlayerSource
    let slot: AudioUnitChainSlot
    let index: Int
    let chainCount: Int
    let onReplace: () -> Void

    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""

    private var status: AudioUnitPluginStatus {
        player.slotStatuses[slot.id] ?? .noPluginSelected
    }

    private var presets: [AudioUnitPreset] {
        player.slotPresets[slot.id] ?? []
    }

    private var activePresetLabel: String {
        guard let id = player.slotActivePresetIDs[slot.id],
              let p = presets.first(where: { $0.id == id }) else { return "None" }
        return p.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(index + 1).")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 18, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    Text(slot.selection.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Text(slot.selection.manufacturerName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    player.moveSlot(from: index, to: index - 1)
                } label: { Image(systemName: "arrow.up") }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    player.moveSlot(from: index, to: index + 2)
                } label: { Image(systemName: "arrow.down") }
                .buttonStyle(.borderless)
                .disabled(index >= chainCount - 1)

                Button {
                    player.openPluginWindow(slotId: slot.id)
                } label: { Image(systemName: "rectangle.expand.vertical") }
                .buttonStyle(.borderless)
                .help("Open plugin editor window")
                .disabled(!status.isActive)

                Button(role: .destructive) {
                    player.removePluginSlot(id: slot.id)
                } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Remove this plugin")
            }

            HStack(spacing: 12) {
                Toggle("Enabled", isOn: Binding(
                    get: { slot.isEnabled },
                    set: { player.setSlotEnabled(id: slot.id, enabled: $0) }
                ))
                .toggleStyle(.checkbox)

                Button("Replace…", action: onReplace)

                if status.isActive, !presets.isEmpty {
                    let factoryPresets = presets.filter(\.isFactory)
                    let userPresets = presets.filter(\.isUser)
                    Menu {
                        if !factoryPresets.isEmpty {
                            Section("Factory") {
                                ForEach(factoryPresets) { p in
                                    Button(p.name) { player.applyPreset(p, toSlot: slot.id) }
                                }
                            }
                        }
                        if !userPresets.isEmpty {
                            Section("Saved") {
                                ForEach(userPresets) { p in
                                    Button(p.name) { player.applyPreset(p, toSlot: slot.id) }
                                }
                            }
                            Divider()
                            ForEach(userPresets) { p in
                                Button("Delete \"\(p.name)\"", role: .destructive) {
                                    try? player.deletePreset(p, fromSlot: slot.id)
                                }
                            }
                        }
                    } label: {
                        Text("Preset: \(activePresetLabel)")
                            .lineLimit(1)
                    }
                    Button("Save…") {
                        newPresetName = ""
                        showSavePresetAlert = true
                    }
                }

                Spacer()
                Text(status.shortDisplayText.isEmpty ? "" : status.shortDisplayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .alert("Save Preset for \(slot.selection.name)", isPresented: $showSavePresetAlert) {
            TextField("Preset name", text: $newPresetName)
            Button("Save") {
                let name = newPresetName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                try? player.saveCurrentAsPreset(named: name, forSlot: slot.id)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Plugin picker sheet

struct AudioUnitPluginPickerSheet: View {
    var onSelect: (AudioUnitPluginSelection) -> Void

    @State private var plugins: [AudioUnitPluginSelection] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredPlugins: [AudioUnitPluginSelection] {
        guard !searchText.isEmpty else { return plugins }
        let needle = searchText.lowercased()
        return plugins.filter {
            $0.name.lowercased().contains(needle) ||
            $0.manufacturerName.lowercased().contains(needle)
        }
    }

    private var groupedPlugins: [(manufacturer: String, plugins: [AudioUnitPluginSelection])] {
        let groups = Dictionary(grouping: filteredPlugins, by: { $0.manufacturerName })
        return groups
            .map { (manufacturer: $0.key, plugins: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.manufacturer < $1.manufacturer }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Audio Unit Plugin")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()

            Text("Third-party Audio Units run inside TangoDisplay at your own risk. An unstable plugin may interrupt playback.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if isLoading {
                ProgressView("Scanning plugins…")
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if plugins.isEmpty {
                Text("No Audio Unit effect plugins found.")
                    .foregroundColor(.secondary)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top, 8)

                List {
                    ForEach(groupedPlugins, id: \.manufacturer) { group in
                        Section(group.manufacturer) {
                            ForEach(group.plugins) { plugin in
                                Button {
                                    onSelect(plugin)
                                } label: {
                                    Text(plugin.name)
                                        .font(.system(size: 13))
                                        .contentShape(Rectangle())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 420, height: 520)
        .task {
            let manager = AudioUnitPluginManager()
            plugins = manager.availableEffects()
            isLoading = false
        }
    }
}
