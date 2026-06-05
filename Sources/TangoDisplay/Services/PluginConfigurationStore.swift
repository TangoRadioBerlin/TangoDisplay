import Combine
import Foundation
import TangoDisplayCore

final class PluginConfigurationStore: ObservableObject {

    @Published private(set) var configurations: [PluginChainConfiguration] = []
    @Published private(set) var defaultConfigurationID: UUID?

    private let saveURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("TangoDisplay")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pluginConfigurations.json")
    }()

    init() { load() }

    // MARK: - Mutations

    func add(name: String, slotStates: [PluginSlotState]) {
        let config = PluginChainConfiguration(name: name, slotStates: slotStates)
        configurations.append(config)
        save()
    }

    func rename(id: UUID, to newName: String) {
        guard let idx = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[idx].name = newName
        save()
    }

    func delete(id: UUID) {
        configurations.removeAll { $0.id == id }
        if defaultConfigurationID == id { defaultConfigurationID = nil }
        save()
    }

    func setDefault(id: UUID?) {
        defaultConfigurationID = id
        save()
    }

    func configuration(id: UUID) -> PluginChainConfiguration? {
        configurations.first { $0.id == id }
    }

    // MARK: - Persistence

    private struct StoredData: Codable {
        var configurations: [PluginChainConfiguration]
        var defaultConfigurationID: UUID?
    }

    private func save() {
        let stored = StoredData(configurations: configurations, defaultConfigurationID: defaultConfigurationID)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        // Try new format first, fall back to legacy array format.
        if let stored = try? JSONDecoder().decode(StoredData.self, from: data) {
            configurations = stored.configurations
            defaultConfigurationID = stored.defaultConfigurationID
        } else if let legacy = try? JSONDecoder().decode([PluginChainConfiguration].self, from: data) {
            configurations = legacy
        }
    }
}
