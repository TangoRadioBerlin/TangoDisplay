import Foundation

/// Identifies an Audio Unit by component (manufacturer + subtype four-char codes),
/// independent of any one slot — the unit hosting decisions are made at.
public struct PluginComponentKey: Codable, Hashable {
    public let manufacturer: UInt32
    public let subType: UInt32

    public init(manufacturer: UInt32, subType: UInt32) {
        self.manufacturer = manufacturer
        self.subType = subType
    }

    public init(manufacturer: String, subType: String) {
        self.init(manufacturer: Self.fourCharCode(manufacturer), subType: Self.fourCharCode(subType))
    }

    public init(_ selection: AudioUnitPluginSelection) {
        self.init(manufacturer: selection.componentManufacturer, subType: selection.componentSubType)
    }

    /// "FabF/FQ4p" — for logs and notices.
    public var displayCode: String { Self.string(manufacturer) + "/" + Self.string(subType) }

    public static func fourCharCode(_ string: String) -> UInt32 {
        string.utf8.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private static func string(_ code: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> UInt32($0)) & 0xFF) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Out-of-process hosting isolates plugin crashes, but wraps the editor in a remote
/// view whose size the host cannot change — the window is stuck at the editor's
/// first size. In-process hosting lets the editor resize with its window, at the
/// cost of that isolation, so it is chosen per plugin.
public enum PluginHostingRules {
    public static func loadsInProcess(_ key: PluginComponentKey, builtIn: Set<PluginComponentKey>,
                                      optIns: Set<PluginComponentKey>) -> Bool {
        builtIn.contains(key) || optIns.contains(key)
    }

    /// Run at launch. `loadedAtExit` is the set of opted-in plugins that were loaded
    /// in-process when the app last stopped without a clean quit — any of them may
    /// have taken the app down, so all of them go back to out-of-process.
    public static func recover(optIns: Set<PluginComponentKey>, loadedAtExit: Set<PluginComponentKey>)
        -> (optIns: Set<PluginComponentKey>, revoked: Set<PluginComponentKey>) {
        let revoked = optIns.intersection(loadedAtExit)
        return (optIns.subtracting(revoked), revoked)
    }
}
