import Foundation
import TangoDisplayCore

func runMusicStartRefreshTests() {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    suite("MusicLibraryScanPolicy.needsReload — coalesce library scans by age") {
        test("a table that was never loaded always needs a reload") {
            try expect(MusicLibraryScanPolicy.needsReload(loadedAt: nil, now: t0, minAge: 30))
        }
        test("a table younger than minAge is reused") {
            try expect(!MusicLibraryScanPolicy.needsReload(loadedAt: t0, now: t0.addingTimeInterval(29), minAge: 30))
        }
        test("a table at or past minAge reloads") {
            try expect(MusicLibraryScanPolicy.needsReload(loadedAt: t0, now: t0.addingTimeInterval(30), minAge: 30))
        }
        test("minAge 0 forces a reload") {
            try expect(MusicLibraryScanPolicy.needsReload(loadedAt: t0, now: t0, minAge: 0))
        }
    }

    suite("MusicLibraryScanPolicy.shouldRebuildPathIndex — keep the index, rebuild sparingly") {
        test("no index yet: build it") {
            try expect(MusicLibraryScanPolicy.shouldRebuildPathIndex(
                hasIndex: false, staleSinceReload: false, knownMiss: false, lastBuilt: nil, now: t0))
        }
        test("no index yet builds even for a known miss (first lookup after a forced reset)") {
            try expect(MusicLibraryScanPolicy.shouldRebuildPathIndex(
                hasIndex: false, staleSinceReload: true, knownMiss: true, lastBuilt: nil, now: t0))
        }
        test("a miss against an index that is current never rebuilds") {
            try expect(!MusicLibraryScanPolicy.shouldRebuildPathIndex(
                hasIndex: true, staleSinceReload: false, knownMiss: false,
                lastBuilt: t0, now: t0.addingTimeInterval(600)))
        }
        test("a new miss against a stale index rebuilds once the interval has passed") {
            try expect(MusicLibraryScanPolicy.shouldRebuildPathIndex(
                hasIndex: true, staleSinceReload: true, knownMiss: false,
                lastBuilt: t0, now: t0.addingTimeInterval(60)))
        }
        test("a new miss against a stale index is rate limited") {
            try expect(!MusicLibraryScanPolicy.shouldRebuildPathIndex(
                hasIndex: true, staleSinceReload: true, knownMiss: false,
                lastBuilt: t0, now: t0.addingTimeInterval(59)))
        }
        test("a path that already missed a full index (a Finder file) never triggers a rebuild") {
            try expect(!MusicLibraryScanPolicy.shouldRebuildPathIndex(
                hasIndex: true, staleSinceReload: true, knownMiss: true,
                lastBuilt: t0, now: t0.addingTimeInterval(3600)))
        }
    }

    suite("musicStartUpdates — diff setlist entries against the library") {
        let a = UUID(), b = UUID(), c = UUID()
        test("an entry the library does not know is left untouched") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: nil, start: 12, end: nil)],
                lookups: [:])
            try expect(u.isEmpty)
        }
        test("an unchanged entry produces no update") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: 12, end: nil)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: 12, end: nil)])
            try expect(u.isEmpty)
        }
        test("a start time edited in Music is picked up") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: 12, end: nil)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: 20, end: nil)])
            try expectEqual(u, [MusicStartUpdate(id: a, persistentID: "AA", start: 20, end: nil)])
        }
        test("a start time removed in Music clears the cached value") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: 12, end: nil)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: nil, end: nil)])
            try expectEqual(u, [MusicStartUpdate(id: a, persistentID: "AA", start: nil, end: nil)])
        }
        test("a legacy entry gets its persistent ID backfilled even without a start time") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: nil, start: nil, end: nil)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: nil, end: nil)])
            try expectEqual(u, [MusicStartUpdate(id: a, persistentID: "AA", start: nil, end: nil)])
        }
        test("the stop time is ignored unless the caller asks for it") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: 12, end: nil)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: 12, end: 90)])
            try expect(u.isEmpty)
        }
        test("includeStop imports a Music stop time as the entry's trim end") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: 12, end: nil)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: 12, end: 90)],
                includeStop: true)
            try expectEqual(u, [MusicStartUpdate(id: a, persistentID: "AA", start: 12, end: 90)])
        }
        test("includeStop never clears a manual trim end when Music has no stop time") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: 12, end: 75)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: 12, end: nil)],
                includeStop: true)
            try expect(u.isEmpty)
        }
        test("without includeStop an update carries the entry's own trim end through") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: nil, end: 75)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: 5, end: 90)])
            try expectEqual(u, [MusicStartUpdate(id: a, persistentID: "AA", start: 5, end: 75)])
        }
        test("updates keep the setlist order and skip unchanged rows") {
            let u = musicStartUpdates(
                entries: [MusicStartSnapshot(id: a, persistentID: "AA", start: 1, end: nil),
                          MusicStartSnapshot(id: b, persistentID: "BB", start: 2, end: nil),
                          MusicStartSnapshot(id: c, persistentID: nil, start: nil, end: nil)],
                lookups: [a: MusicStartLookup(persistentID: "AA", start: 3, end: nil),
                          b: MusicStartLookup(persistentID: "BB", start: 2, end: nil),
                          c: MusicStartLookup(persistentID: "CC", start: 4, end: nil)])
            try expectEqual(u.map(\.id), [a, c])
        }
    }
}
