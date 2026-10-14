import AVFoundation
import OSLog
import TangoDisplayCore

enum AudioUnitPluginError: Error, LocalizedError {
    case componentNotFound
    case instantiationFailed(String)
    case graphConnectionFailed(String)
    case uiUnavailable

    var errorDescription: String? {
        switch self {
        case .componentNotFound:           return "Audio Unit component not found on this Mac."
        case .instantiationFailed(let r):  return "Audio Unit instantiation failed: \(r)"
        case .graphConnectionFailed(let r): return "Audio graph connection failed: \(r)"
        case .uiUnavailable:               return "This plugin does not provide an editor UI."
        }
    }
}

final class AudioUnitPluginManager {

    func availableEffects() -> [AudioUnitPluginSelection] {
        // Enumerate both plain effects (aufx) and music effects (aumf). Many
        // modern plugins (e.g. FabFilter Pro-Q 4) register as aumf so they can
        // accept MIDI input; they still process audio like any other effect in
        // an AVAudioEngine chain (MIDI is optional), so they belong here.
        // Instruments (aumu) are deliberately excluded — they are synths.
        let manager = AVAudioUnitComponentManager.shared()
        let effectTypes: [OSType] = [kAudioUnitType_Effect, kAudioUnitType_MusicEffect]
        let components = effectTypes.flatMap { type -> [AVAudioUnitComponent] in
            let desc = AudioComponentDescription(
                componentType: type,
                componentSubType: 0,
                componentManufacturer: 0,
                componentFlags: 0,
                componentFlagsMask: 0
            )
            return manager.components(matching: desc)
        }
        return components
            .map { component in
                AudioUnitPluginSelection(
                    id: UUID(),
                    name: component.name,
                    manufacturerName: component.manufacturerName,
                    componentType: component.audioComponentDescription.componentType,
                    componentSubType: component.audioComponentDescription.componentSubType,
                    componentManufacturer: component.audioComponentDescription.componentManufacturer
                )
            }
            .sorted { ($0.manufacturerName, $0.name) < ($1.manufacturerName, $1.name) }
    }

    func isAvailable(_ selection: AudioUnitPluginSelection) -> Bool {
        let desc = AudioComponentDescription(
            componentType: OSType(selection.componentType),
            componentSubType: OSType(selection.componentSubType),
            componentManufacturer: OSType(selection.componentManufacturer),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return !AVAudioUnitComponentManager.shared().components(matching: desc).isEmpty
    }

    func instantiate(_ selection: AudioUnitPluginSelection,
                     inProcessOptIns: Set<PluginComponentKey> = []) async throws -> AVAudioUnit {
        let desc = AudioComponentDescription(
            componentType: OSType(selection.componentType),
            componentSubType: OSType(selection.componentSubType),
            componentManufacturer: OSType(selection.componentManufacturer),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let components = AVAudioUnitComponentManager.shared().components(matching: desc)
        guard let component = components.first else {
            throw AudioUnitPluginError.componentNotFound
        }

        // Hosting mode: default to out-of-process (OOP). OOP is Apple's
        // standard hosting path — it isolates plugin crashes inside the AU's
        // own process and is what 3rd-party plugins are tested against. Some
        // V2 plugins (e.g. FabFilter Pro-Q 4) crash the *host* outright when
        // their editor is created in-process via the V2→V3 bridge, so loading
        // them in-process is unsafe.
        //
        // Under OOP the editor is also stuck at its first size: the remote view's
        // container cannot be resized by the host (measured with FabFilter Pro-Q
        // 4.12 — neither window drag nor setContentSize moves it). Users can opt a
        // plugin into in-process hosting for that (`inProcessOptIns`); a crash
        // guard (InProcessPluginSentinel) withdraws the opt-in after a crash.
        //
        // Exception: the in-process allowlist below. A few V2 plugins only
        // relay UI resize events to the host when loaded *in-process*; under
        // the OOP V2→V3 bridge their view is wrapped in NSRemoteView, which
        // doesn't surface remote-side frame changes, so plugin-driven window
        // resizing (e.g. MJUC's expander) silently breaks. For those we load
        // in-process and accept the lack of crash isolation.
        let loadInProcess = PluginHostingRules.loadsInProcess(
            PluginComponentKey(selection), builtIn: Self.inProcessAllowlist, optIns: inProcessOptIns)

        let primary: AudioComponentInstantiationOptions = loadInProcess ? [] : .loadOutOfProcess
        let fallback: AudioComponentInstantiationOptions = loadInProcess ? .loadOutOfProcess : []

        if let unit = await Self.tryInstantiate(desc: desc, options: primary) {
            return unit
        }
        if let unit = await Self.tryInstantiate(desc: desc, options: fallback) {
            return unit
        }
        throw AudioUnitPluginError.instantiationFailed("instantiation returned nil")
    }

    // MARK: - In-process hosting allowlist

    /// V2 plugins that must load in-process for plugin-driven window resize
    /// to work. Loaded out-of-process their editor is wrapped in NSRemoteView,
    /// which swallows the frame-change events the host needs to grow the
    /// window. Keyed on (manufacturer, subType) four-char codes. Keep this
    /// list as small as possible — in-process plugins are not crash-isolated.
    static let inProcessAllowlist: Set<PluginComponentKey> = [
        // Klanghelm MJUC — its expander panel grows the editor at runtime.
        PluginComponentKey(manufacturer: "KlHm", subType: "MJUC"),
    ]

    /// Whether this plugin is on the built-in allowlist (always in-process; the
    /// per-plugin opt-in does not apply to it).
    static func isBuiltInInProcess(_ selection: AudioUnitPluginSelection) -> Bool {
        inProcessAllowlist.contains(PluginComponentKey(selection))
    }

    private static func tryInstantiate(
        desc: AudioComponentDescription,
        options: AudioComponentInstantiationOptions
    ) async -> AVAudioUnit? {
        await withCheckedContinuation { continuation in
            AVAudioUnit.instantiate(with: desc, options: options) { avUnit, _ in
                continuation.resume(returning: avUnit)
            }
        }
    }
}
