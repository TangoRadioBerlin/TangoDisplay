import Foundation
import TangoDisplayCore

/// Crash guard for opted-in in-process plugins. While one is loaded (or loading) its
/// component key sits in UserDefaults; a clean quit clears it. Finding it at the next
/// launch means the app died with that plugin inside it, and the opt-in is withdrawn
/// (`AppSettings` init → `PluginHostingRules.recover`), so a crashing plugin cannot
/// take the app down launch after launch.
enum InProcessPluginSentinel {
    static let key = "TangoDisplay.inProcessPluginsLoaded"

    static func set(_ keys: Set<PluginComponentKey>) {
        let ud = UserDefaults.standard
        if keys.isEmpty {
            ud.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(Array(keys)) {
            ud.set(data, forKey: key)
        }
        // Must be on disk before the plugin gets a chance to crash the process.
        ud.synchronize()
    }

    static func clear() { set([]) }
}
