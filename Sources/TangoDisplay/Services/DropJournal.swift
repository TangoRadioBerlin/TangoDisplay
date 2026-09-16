// DropJournal.swift
// One line per drop resolution in Application Support — the unified log's
// `.default` summary turned out not to be persisted on the DJ's Mac, which
// left a whole evening's worth of failed drops unreconstructible. Counts and
// pasteboard types only, never file paths. Bounded via DropJournalRules.

import Foundation
import TangoDisplayCore

enum DropJournal {

    static let maxBytes = 256 * 1024

    private static let queue = DispatchQueue(label: "com.tangodisplay.dropjournal", qos: .utility)
    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("TangoDisplay", isDirectory: true)
            .appendingPathComponent("drop-log.txt")
    }

    static func append(entry: String, branch: String, requested: Int, resolved: Int,
                       unreadable: Int, musicIDs: Int, types: String) {
        let line = DropJournalRules.line(timestamp: stamp.string(from: Date()), entry: entry, branch: branch,
                                         requested: requested, resolved: resolved, unreadable: unreadable,
                                         musicIDs: musicIDs, types: types) + "\n"
        queue.async { write(line) }
    }

    private static func write(_ line: String) {
        let url = fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        text += line
        if text.utf8.count > maxBytes {
            text = DropJournalRules.trimmedToTail(text, maxBytes: maxBytes)
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
