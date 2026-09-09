import Foundation

/// Pure decision over a remote-load path, given filesystem facts the caller already
/// gathered elsewhere. Kept AppKit/Foundation-I/O-free so the actual `FileManager` calls
/// (genuinely blocking on an unreachable network mount) can be pushed off the MainActor
/// by the caller without dragging this decision logic along with them.
public enum RemoteLoadPathRules {

    /// Filesystem facts about a candidate path, gathered by the caller (off-main).
    public struct FileProbeResult {
        public let exists: Bool
        public let isDirectory: Bool
        public let isReadable: Bool

        public init(exists: Bool, isDirectory: Bool, isReadable: Bool) {
            self.exists = exists
            self.isDirectory = isDirectory
            self.isReadable = isReadable
        }
    }

    /// Returns a `RemoteRejectReason` if `path` may not be loaded, or `nil` if it's valid.
    public static func reason(for path: String, probe: FileProbeResult,
                              supportedExtensions: Set<String>) -> String? {
        guard path.hasPrefix("/") else { return RemoteRejectReason.pathNotAllowed }
        guard probe.exists else { return RemoteRejectReason.fileNotFound }
        if probe.isDirectory { return RemoteRejectReason.unsupportedType }
        guard probe.isReadable else { return RemoteRejectReason.unreadable }
        let ext = (path as NSString).pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { return RemoteRejectReason.unsupportedType }
        return nil
    }
}
