import SwiftUI
import TangoDisplayCore

struct PluginChainPopoverView: View {
    @ObservedObject var player: LocalPlayerSource
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plugin Chain")
                .font(.headline)

            Toggle("Enable chain", isOn: Binding(
                get: { settings.audioUnitPluginEnabled },
                set: { enabled in
                    if enabled { player.enableAudioUnitPlugin() }
                    else       { player.disableAudioUnitPlugin() }
                }
            ))

            Toggle("Bypass chain", isOn: Binding(
                get: { settings.audioUnitPluginBypassed },
                set: { player.bypassAudioUnitPlugin($0) }
            ))
            .disabled(!settings.audioUnitPluginEnabled || settings.audioUnitPluginChain.isEmpty)

            Divider()

            if settings.audioUnitPluginChain.isEmpty {
                Text("No plugins configured. Add plugins in Player Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(settings.audioUnitPluginChain.enumerated()), id: \.element.id) { index, slot in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(slot.selection.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Text(slot.selection.manufacturerName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { slot.isEnabled },
                            set: { player.setSlotEnabled(id: slot.id, enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .help(slot.isEnabled ? "Disable this slot" : "Enable this slot")

                        Button {
                            player.openPluginWindow(slotId: slot.id)
                        } label: {
                            Image(systemName: "rectangle.expand.vertical")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!(player.slotStatuses[slot.id]?.isActive ?? false))
                        .help("Open plugin editor")
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
