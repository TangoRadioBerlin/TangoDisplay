// DropPasteboardResolver.swift
// Turns a drag/paste pasteboard into file URLs — the single resolver behind
// every way tracks enter the setlist (window-level AppKit drop, SwiftUI List
// row drop, ⌘V paste).
//
// Music.app drags are heterogeneous: a multi-track selection mixes items that
// carry a plain public.file-url, items that only carry the legacy promise
// string, and cloud-only items that carry nothing readable. The resolver
// therefore keeps a requested-vs-resolved count (`DropResolution.unreadable`)
// so the UI can report any shortfall instead of silently inserting a subset.
//
// Every pasteboard DATA read (readObjects / string(forType:) /
// propertyList(forType:)) can force a lazily-declaring source app to provide
// the data synchronously — a cross-process wait. `resolve` must therefore run
// INSIDE the drop callout (drag pasteboard live, source still serving) and
// each read is preceded by a FreezeWatchdog breadcrumb.

import AppKit
import os.log
import TangoDisplayCore

// MARK: - Result types

struct DropResolution {
    var urls: [URL]
    /// Items the source advertised (pasteboard item count, or more when a
    /// metadata plist lists additional tracks).
    var requested: Int
    var branch: DropPayloadKind
    /// Per-item pasteboard types — for the persisted log only, never paths.
    var itemTypes: [Set<String>]

    /// Items that did not yield a file URL.
    var unreadable: Int { max(0, requested - urls.count) }

    /// Union in URLs from a second source (e.g. NSItemProvider fallback).
    mutating func merge(_ extra: [URL], requestedAtLeast: Int) {
        urls = DropPasteboardRules.dedupe(urls + extra)
        requested = max(requested, requestedAtLeast)
    }
}

enum DropResolutionResult {
    case immediate(DropResolution)
    /// Branches that resolve asynchronously (modern file promises, AppleScript
    /// selection). `requested`/`branch` are known now; `finish` delivers the
    /// full resolution on the main queue exactly once.
    case deferred(DropResolution, finish: (@escaping @MainActor (DropResolution) -> Void) -> Void)

    /// The resolution, awaiting a deferred branch when necessary.
    @MainActor
    var value: DropResolution {
        get async {
            switch self {
            case .immediate(let r): return r
            case .deferred(_, let finish):
                return await withCheckedContinuation { continuation in
                    finish { continuation.resume(returning: $0) }
                }
            }
        }
    }
}

// MARK: - Resolver

enum DropPasteboardResolver {

    static let log = OSLog(subsystem: DiagnosticLog.subsystem, category: "musicdrop")
    private static let diagLog = DiagnosticLog.shared

    private static let promiseQueue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        return q
    }()

    private static let legacyPromiseURLType      = NSPasteboard.PasteboardType(DropPasteboardType.legacyPromiseURL)
    private static let musicMetadataType         = NSPasteboard.PasteboardType(DropPasteboardType.musicMetadata)

    /// Types of every item on the pasteboard, in item order.
    static func itemTypes(of pasteboard: NSPasteboard) -> [Set<String>] {
        (pasteboard.pasteboardItems ?? []).map { Set($0.types.map(\.rawValue)) }
    }

    static var modernPromiseTypes: Set<String> {
        Set(NSFilePromiseReceiver.readableDraggedTypes)
    }

    /// Synchronous; MUST run inside the drop callout. `draggingInfo == nil`
    /// (row drops, paste) disables legacy materialisation — the destination
    /// URL of `namesOfPromisedFilesDropped` is bound to the dragging info.
    static func resolve(_ pasteboard: NSPasteboard,
                        draggingInfo: NSDraggingInfo?,
                        diagEnabled: Bool) -> DropResolutionResult {
        let items = pasteboard.pasteboardItems ?? []
        let types = itemTypes(of: pasteboard)
        let union = types.reduce(into: Set<String>()) { $0.formUnion($1) }
        let kind = DropPasteboardRules.classify(itemTypes: types, modernPromiseTypes: modernPromiseTypes)
        var base = DropResolution(urls: [], requested: items.count, branch: kind, itemTypes: types)

        os_log("resolve kind=%{public}@ items=%d types=%{public}@", log: log, type: .info,
               kind.rawValue, items.count, DropPasteboardRules.typeSummary(itemTypes: types))

        // 1. Modern NSFilePromiseReceiver — for future Music.app versions.
        // Cheap types check first: readObjects forces promise data, so don't
        // touch it for drags that never advertised a promise flavor.
        if kind == .modernFilePromise {
            if diagEnabled { diagLog.record("drop.branch1.readFilePromises") }
            if let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self],
                                                      options: nil) as? [NSFilePromiseReceiver],
               !promises.isEmpty
            {
                base.branch = .modernFilePromise
                base.requested = max(base.requested, promises.count)
                return .deferred(base) { finish in
                    acceptFilePromises(promises, base: base, finish: finish)
                }
            }
        }

        // 2. Legacy file-promise — Music.app on Sequoia for iTunes-purchased AAC.
        if union.contains(DropPasteboardType.legacyPromiseURL)
            || union.contains(DropPasteboardType.legacyPromiseContents)
        {
            base.branch = .legacyFilePromise
            return .immediate(acceptLegacyFilePromise(items: items, base: base,
                                                      draggingInfo: draggingInfo, diagEnabled: diagEnabled))
        }

        // 3. Legacy plist path — pre-Sequoia purchased AAC.
        if union.contains(DropPasteboardType.musicMetadata) {
            if diagEnabled { diagLog.record("drop.branch3.readMusicMetadata") }
            let (urls, listed) = resolveViaMusicMetadata(items: items)
            if !urls.isEmpty {
                base.branch = .musicMetadata
                base.urls = urls
                base.requested = max(base.requested, listed)
                return .immediate(base)
            }
        }

        // 4. Plain file URL — Finder, Swinsian, AIFF-from-Music drags.
        if union.contains(DropPasteboardType.fileURL) {
            if diagEnabled { diagLog.record("drop.branch4.readFileURLs") }
            let pbURLs = pasteboard.readObjects(forClasses: [NSURL.self],
                                                 options: [.urlReadingFileURLsOnly: true]) as? [URL]
            if let pbURLs = pbURLs, !pbURLs.isEmpty {
                os_log("file-url path resolved %d url(s)", log: log, type: .info, pbURLs.count)
                base.branch = .fileURL
                base.urls = DropPasteboardRules.dedupe(pbURLs)
                return .immediate(base)
            }
            // Per-item fallback: foobar2000 writes public.file-url as a bare
            // POSIX path (readObjects yields nothing for those) — mirror the
            // ⌘V paste path and parse each item string directly.
            var itemURLs: [URL] = []
            for item in items {
                guard let str = item.string(forType: .fileURL),
                      let url = DropPasteboardRules.fileURL(fromPasteboardString: str)
                else { continue }
                itemURLs.append(url)
            }
            if !itemURLs.isEmpty {
                os_log("file-url per-item fallback resolved %d url(s)", log: log, type: .info, itemURLs.count)
                base.branch = .fileURL
                base.urls = DropPasteboardRules.dedupe(itemURLs)
                return .immediate(base)
            }
        }

        // 5. AppleScript selection fallback — com.apple.itunes.drag only.
        // Deferred off-main: NSAppleScript.executeAndReturnError is a blocking
        // cross-process call and must not run inside the live drag-tracking loop.
        // Reads Music's CURRENT selection, so it is the last resort only.
        if union.contains(DropPasteboardType.itunesDrag) {
            base.branch = .musicSelection
            return .deferred(base) { finish in
                DispatchQueue.global(qos: .userInitiated).async {
                    let urls = resolveViaMusicSelection()
                    var r = base
                    r.urls = DropPasteboardRules.dedupe(urls)
                    Task { @MainActor in finish(r) }
                }
            }
        }

        os_log("resolve yielded zero urls (kind=%{public}@)", log: log, type: .error, kind.rawValue)
        base.branch = .unsupported
        return .immediate(base)
    }

    // MARK: - Persisted summary

    /// One `.default`-level line per drop — persisted by the unified log, so an
    /// incident can be reconstructed afterwards without the diagnostics toggle:
    ///   log show --predicate 'subsystem == "com.tangodisplay" AND category == "musicdrop"' --last 1d
    /// Counts and type identifiers only; never file paths.
    static func logSummary(_ r: DropResolution, entry: String) {
        os_log("drop entry=%{public}@ branch=%{public}@ requested=%d resolved=%d unreadable=%d types=%{public}@",
               log: log, type: .default,
               entry, r.branch.rawValue, r.requested, r.urls.count, r.unreadable,
               DropPasteboardRules.typeSummary(itemTypes: r.itemTypes))
        if r.unreadable > 0 {
            os_log("drop shortfall entry=%{public}@ branch=%{public}@ %d of %d items unreadable; types=%{public}@",
                   log: log, type: .error,
                   entry, r.branch.rawValue, r.unreadable, r.requested,
                   DropPasteboardRules.typeSummary(itemTypes: r.itemTypes, maxItems: 50))
        }
    }

    // MARK: - Branch 2: legacy file promise

    // Music.app on Sequoia advertises com.apple.pasteboard.promised-file-url
    // on the root pasteboard, but in practice only a small subset of per-item
    // NSPasteboardItems carry the promise string — the rest carry just
    // public.file-url. Read file-url first per item and fall back to the
    // promise string, so multi-track drags (e.g. an entire 108-track playlist)
    // aren't truncated to the few items that happen to advertise the promise.
    //
    // If unresolved items remain, ask the source to materialise the promised
    // files — but ONLY for genuine Music.app drags (cloud-only tracks) and only
    // with a dragging info (the destination is bound to it).
    // namesOfPromisedFilesDropped is synchronous: it blocks this drop callout
    // while the source app writes each file. For any other source that
    // advertises a promise flavor alongside file-urls, blocking here risks a
    // cross-process deadlock (the source's drag loop is waiting for our drop
    // reply), so DropPasteboardRules.legacyPromiseAction forbids it and we
    // return whatever resolved instead.
    private static func acceptLegacyFilePromise(items: [NSPasteboardItem],
                                                base: DropResolution,
                                                draggingInfo: NSDraggingInfo?,
                                                diagEnabled: Bool) -> DropResolution {
        var result = base
        if diagEnabled { diagLog.record("drop.branch2.readLegacyPromiseItems") }

        var urls: [URL] = []
        for item in items {
            // Try public.file-url first, then the promise string. Per-item
            // fallback (not `??` on the strings) so a broken file-url doesn't
            // prevent us from trying the promise flavor on the same item —
            // protects the v3.21.4 iTunes-purchased-AAC drag case.
            let candidates = [
                item.string(forType: .fileURL),
                item.string(forType: legacyPromiseURLType),
            ].compactMap { $0 }
            for str in candidates {
                guard let url = DropPasteboardRules.fileURL(fromPasteboardString: str),
                      FileManager.default.fileExists(atPath: url.path)
                else { continue }
                urls.append(url)
                break
            }
        }
        urls = DropPasteboardRules.dedupe(urls)

        // Every pasteboard item counts as advertised: an item whose strings
        // come back nil (lazy provision failed, cloud-only track) is exactly
        // the one that must not vanish from the denominator.
        let isMusicAppSource = DropPasteboardRules.isMusicAppSource(itemTypes: base.itemTypes)
        var action = DropPasteboardRules.legacyPromiseAction(resolved: urls.count,
                                                             advertised: items.count,
                                                             isMusicAppSource: isMusicAppSource)
        if action == .materialize && draggingInfo == nil {
            os_log("promise partial: materialise unavailable (no NSDraggingInfo) — using %d of %d",
                   log: log, type: .info, urls.count, items.count)
            action = urls.isEmpty ? .fail : .acceptPartial
        }

        switch action {
        case .acceptResolved:
            os_log("promise resolved %d url(s) from pasteboard string", log: log, type: .info, urls.count)
            result.urls = urls

        case .acceptPartial:
            os_log("promise partial: using %d of %d advertised (no materialise)",
                   log: log, type: .info, urls.count, items.count)
            result.urls = urls

        case .fail:
            os_log("promise unresolved: nothing readable (items=%d)", log: log, type: .error, items.count)
            result.urls = []

        case .materialize:
            // Cloud-only Music.app tracks — ask Music.app to write cached copies.
            // Synchronous by API design. We rely on Music writing the files
            // before returning; if a file were still pending when the deferred
            // missing-file filter runs, it would be dropped with a "not found"
            // note (accepted residual risk, never observed).
            os_log("promise partial: resolved %d of %d advertised — materialising",
                   log: log, type: .info, urls.count, items.count)
            if diagEnabled { diagLog.record("drop.branch2.materialisePromises") }
            let destDir = filePromiseDestination()
            let names = draggingInfo?.namesOfPromisedFilesDropped(atDestination: destDir) ?? []
            let writtenURLs = names.map { destDir.appendingPathComponent($0) }
            os_log("promise materialised %d file(s) at %{public}@",
                   log: log, type: .info, names.count, destDir.path)
            // Union: locally resolved tracks first, then the materialised copies —
            // Music may only write the subset it actually promised, so dropping
            // `urls` here would lose the local half of a mixed local+cloud drag.
            result.urls = DropPasteboardRules.dedupe(urls + writtenURLs)
        }
        return result
    }

    // MARK: - Branch 1: modern file promises

    // Accept one or more NSFilePromiseReceiver promises, writing the files to a
    // persistent cache directory inside Application Support. Calls `finish`
    // once all promises have either resolved or failed — with the shortfall
    // visible in the resolution rather than swallowed.
    private static func acceptFilePromises(_ promises: [NSFilePromiseReceiver],
                                           base: DropResolution,
                                           finish: @escaping @MainActor (DropResolution) -> Void) {
        let destDir = filePromiseDestination()
        os_log("accepting %d file promise(s) to %{public}@", log: log, type: .info, promises.count, destDir.path)
        let lock = NSLock()
        var receivedURLs: [URL] = []
        let group = DispatchGroup()
        for promise in promises {
            group.enter()
            promise.receivePromisedFiles(atDestination: destDir,
                                          options: [:],
                                          operationQueue: promiseQueue) { url, error in
                if let error = error {
                    os_log("file promise error: %{public}@", log: log, type: .error, String(describing: error))
                } else {
                    os_log("received promised file: %{public}@", log: log, type: .info, url.path)
                    lock.lock(); receivedURLs.append(url); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            var r = base
            r.urls = DropPasteboardRules.dedupe(receivedURLs)
            if r.urls.isEmpty { os_log("file promises yielded zero urls", log: log, type: .error) }
            Task { @MainActor in finish(r) }
        }
    }

    static func filePromiseDestination() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("TangoDisplay/MusicAppDrops", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Branch 3: Music metadata plist

    /// Returns the on-disk URLs listed in the items' metadata plists plus the
    /// number of distinct locations listed (for the requested count — a plist
    /// can list more tracks than there are pasteboard items).
    private static func resolveViaMusicMetadata(items: [NSPasteboardItem]) -> (urls: [URL], listed: Int) {
        var listed: [URL] = []
        for item in items {
            guard let plist = item.propertyList(forType: musicMetadataType) as? [String: Any] else {
                os_log("plist cast failed for pasteboard item", log: log, type: .error)
                continue
            }
            listed.append(contentsOf: DropPasteboardRules.musicMetadataLocations(plist))
        }
        listed = DropPasteboardRules.dedupe(listed)
        // Only accept locations that resolve to a real file; the rest count as
        // unreadable and surface in the feedback.
        let urls = listed.filter { FileManager.default.fileExists(atPath: $0.path) }
        os_log("resolveViaMusicMetadata listed %d, on disk %d", log: log, type: .info, listed.count, urls.count)
        return (urls, listed.count)
    }

    // MARK: - Branch 5: AppleScript selection

    private static func resolveViaMusicSelection() -> [URL] {
        let source = """
        tell application "Music"
            set paths to {}
            repeat with t in selection
                try
                    set end of paths to POSIX path of (location of t as alias)
                end try
            end repeat
            return paths
        end tell
        """
        let script = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        guard let descriptor = script?.executeAndReturnError(&errorInfo) else { return [] }
        var urls: [URL] = []
        if descriptor.numberOfItems > 0 {
            for i in 1...descriptor.numberOfItems {
                if let path = descriptor.atIndex(i)?.stringValue {
                    urls.append(URL(fileURLWithPath: path))
                }
            }
        } else if let path = descriptor.stringValue, !path.isEmpty {
            urls.append(URL(fileURLWithPath: path))
        }
        os_log("music selection fallback resolved %d url(s)", log: log, type: .default, urls.count)
        return urls
    }
}
