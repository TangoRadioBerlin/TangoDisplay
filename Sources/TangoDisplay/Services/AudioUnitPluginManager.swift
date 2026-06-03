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
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: 0,
            componentManufacturer: 0,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitComponentManager.shared()
            .components(matching: desc)
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

    func instantiate(_ selection: AudioUnitPluginSelection) async throws -> AVAudioUnit {
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

        // V3 AUs are designed for out-of-process hosting and crash-isolate
        // cleanly in their XPC service — prefer OOP for them. V2 AUs (the
        // older Cocoa-view kind, e.g. Klanghelm MJUC) only relay UI
        // resize events to the host when loaded *in-process*; under
        // Apple's OOP V2-to-V3 bridge their view is wrapped in
        // NSRemoteView, which doesn't surface remote-side frame changes
        // to the host process. Loading those in-process is required for
        // plugin-driven window resizing (e.g. MJUC's expander) to work.
        // kAudioComponentFlag_IsV3AudioComponent = 1 << 2 (per AudioToolbox/AudioComponent.h).
        // Not exposed in Swift's imported AudioToolbox in older SDKs, so use literal.
        let isV3 = (component.audioComponentDescription.componentFlags & (1 << 2)) != 0

        let primary: AudioComponentInstantiationOptions = isV3 ? .loadOutOfProcess : []
        let fallback: AudioComponentInstantiationOptions = isV3 ? [] : .loadOutOfProcess

        if let unit = await Self.tryInstantiate(desc: desc, options: primary) {
            return unit
        }
        if let unit = await Self.tryInstantiate(desc: desc, options: fallback) {
            return unit
        }
        throw AudioUnitPluginError.instantiationFailed("instantiation returned nil")
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
