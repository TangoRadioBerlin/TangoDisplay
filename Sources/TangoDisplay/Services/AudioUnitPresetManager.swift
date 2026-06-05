import AVFoundation
import Foundation
import OSLog
import TangoDisplayCore

/// Manages factory and user presets for a loaded AVAudioUnit.
///
/// User presets are stored in:
///   ~/Library/Application Support/TangoDisplay/AUPresets/{componentSubType}/
///
/// Each user preset is a JSON file ({uuid}.aupreset) containing the preset name and
/// the AU's full state serialised as a base64-encoded binary property list.
final class AudioUnitPresetManager {

    private let storeURL: URL

    init(for selection: AudioUnitPluginSelection) {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storeURL = appSupport
            .appendingPathComponent("TangoDisplay/AUPresets/\(selection.componentSubType)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
    }

    // MARK: - Factory presets

    func factoryPresets(for avUnit: AVAudioUnit) -> [AudioUnitPreset] {
        guard let raw = avUnit.auAudioUnit.factoryPresets else { return [] }
        return raw.map { p in
            AudioUnitPreset(name: p.name, kind: .factory(number: p.number))
        }
    }

    // MARK: - User presets

    func userPresets() -> [AudioUnitPreset] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: storeURL, includingPropertiesForKeys: nil
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "aupreset" }
            .compactMap { url -> AudioUnitPreset? in
                guard let fileData = try? Data(contentsOf: url),
                      let envelope = try? JSONDecoder().decode(PresetEnvelope.self, from: fileData),
                      let stateData = Data(base64Encoded: envelope.auState) else { return nil }
                return AudioUnitPreset(
                    id: UUID(uuidString: envelope.id) ?? UUID(),
                    name: envelope.name,
                    kind: .user(parameterData: stateData)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func savePreset(name: String, from avUnit: AVAudioUnit) throws -> AudioUnitPreset {
        guard let fullState = avUnit.auAudioUnit.fullState else {
            throw AudioUnitPresetError.noState
        }
        let auState = try AUStateCodec.encode(fullState)
        let stateData = Data(base64Encoded: auState)!
        let id = UUID()
        let envelope = PresetEnvelope(id: id.uuidString, name: name, auState: auState)
        let fileData = try JSONEncoder().encode(envelope)
        let fileURL = storeURL.appendingPathComponent("\(id.uuidString).aupreset")
        try fileData.write(to: fileURL, options: .atomic)
        return AudioUnitPreset(id: id, name: name, kind: .user(parameterData: stateData))
    }

    func deletePreset(_ preset: AudioUnitPreset) throws {
        let fileURL = storeURL.appendingPathComponent("\(preset.id.uuidString).aupreset")
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Apply

    func applyPreset(_ preset: AudioUnitPreset, to avUnit: AVAudioUnit,
                     originator: AUParameterObserverToken? = nil) throws {
        switch preset.kind {
        case .factory(let number):
            let auPreset = AUAudioUnitPreset()
            auPreset.number = number
            auPreset.name = preset.name
            avUnit.auAudioUnit.currentPreset = auPreset

        case .user(let stateData):
            guard let fullState = try PropertyListSerialization
                    .propertyList(from: stateData, format: nil) as? [String: Any] else {
                throw AudioUnitPresetError.invalidState
            }
            avUnit.auAudioUnit.fullState = fullState
        }
    }

    // MARK: - Types

    private struct PresetEnvelope: Codable {
        let id: String
        let name: String
        let auState: String   // base64-encoded binary plist of avUnit.auAudioUnit.fullState
    }
}

enum AudioUnitPresetError: LocalizedError {
    case noState
    case invalidState

    var errorDescription: String? {
        switch self {
        case .noState:    return "Plugin does not provide state for saving"
        case .invalidState: return "Preset data could not be decoded"
        }
    }
}
