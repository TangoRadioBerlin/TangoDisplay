// Lightweight test runner — no XCTest or Xcode required.
// Run with: swift run TangoDisplayTests
//
// Convention:
//   suite("SuiteName") { ... }      — groups tests, prints header
//   test("name") { ... }            — individual test, catches thrown errors
//   expect(_ condition, file:line:) — assertion; throws on failure

import Foundation
import TangoDisplayCore

// MARK: - Minimal test framework

private var totalPassed = 0
private var totalFailed = 0
private var currentSuite = ""

struct TestFailure: Error {
    let message: String
    let file: StaticString
    let line: Int
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String = "",
    file: StaticString = #file,
    line: Int = #line
) throws {
    guard condition() else {
        let msg = message.isEmpty ? "Assertion failed" : message
        throw TestFailure(message: msg, file: file, line: line)
    }
}

func expectEqual<T: Equatable>(
    _ a: T,
    _ b: T,
    file: StaticString = #file,
    line: Int = #line
) throws {
    try expect(a == b, "Expected \(a) == \(b)", file: file, line: line)
}

func expectNil<T>(_ value: T?, file: StaticString = #file, line: Int = #line) throws {
    try expect(value == nil, "Expected nil but got \(String(describing: value))", file: file, line: line)
}

func expectNotNil<T>(_ value: T?, file: StaticString = #file, line: Int = #line) throws {
    try expect(value != nil, "Expected non-nil value", file: file, line: line)
}

func suite(_ name: String, _ body: () -> Void) {
    currentSuite = name
    print("\n── \(name) ──")
    body()
}

func test(_ name: String, body: () throws -> Void) {
    do {
        try body()
        print("  ✓ \(name)")
        totalPassed += 1
    } catch let failure as TestFailure {
        print("  ✗ \(name)")
        print("      \(failure.message) (\(failure.file):\(failure.line))")
        totalFailed += 1
    } catch {
        print("  ✗ \(name) — unexpected error: \(error)")
        totalFailed += 1
    }
}

// MARK: - CortinaDetector tests

func runCortinaDetectorTests() {
    suite("CortinaDetector — Allowlist only") {
        test("matching genre is cortina") {
            let d = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                    useDenylist: false, denylistGenres: [])
            try expect(d.isCortina(genre: "Cortina"))
        }
        test("non-matching genre is not cortina") {
            let d = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                    useDenylist: false, denylistGenres: [])
            try expect(!d.isCortina(genre: "Tango"))
        }
        test("case insensitive — CORTINA") {
            let d = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                    useDenylist: false, denylistGenres: [])
            try expect(d.isCortina(genre: "CORTINA"))
            try expect(d.isCortina(genre: "cortina"))
            try expect(d.isCortina(genre: "Cortina"))
        }
        test("empty genre is NOT cortina under allowlist-only") {
            let d = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                    useDenylist: false, denylistGenres: [])
            try expect(!d.isCortina(genre: ""))
        }
    }

    suite("CortinaDetector — Allowlist partial match") {
        let d = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                allowlistPartialGenres: ["cortina"],
                                useDenylist: false, denylistGenres: [])
        test("word-boundary partial matches") {
            try expect(d.isCortina(genre: "Cortina Instrumental"))   // prefix + space
            try expect(d.isCortina(genre: "Alt Cortina"))            // space + suffix
            try expect(d.isCortina(genre: "cortina"))                // exact still works
        }
        test("non-word-boundary substring does NOT match") {
            try expect(!d.isCortina(genre: "Cortinaland"))
        }
        test("partial off → only exact matches") {
            let exactOnly = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                            useDenylist: false, denylistGenres: [])
            try expect(!exactOnly.isCortina(genre: "Cortina Instrumental"))
            try expect(exactOnly.isCortina(genre: "Cortina"))
        }
    }

    suite("CortinaDetector — Denylist only") {
        let d = CortinaDetector(useAllowlist: false, allowlistGenres: [],
                                useDenylist: true, denylistGenres: ["tango", "vals", "milonga"])
        test("dance genre is not cortina") {
            try expect(!d.isCortina(genre: "Tango"))
            try expect(!d.isCortina(genre: "Vals"))
            try expect(!d.isCortina(genre: "Milonga"))
        }
        test("non-dance genre is cortina") {
            try expect(d.isCortina(genre: "Pop"))
            try expect(d.isCortina(genre: "Cortina"))
        }
        test("empty genre is cortina") {
            try expect(d.isCortina(genre: ""))
        }
        test("case insensitive — TANGO") {
            try expect(!d.isCortina(genre: "TANGO"))
            try expect(!d.isCortina(genre: "Vals"))
        }
    }

    suite("CortinaDetector — Both rules (EITHER match → cortina)") {
        let d = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                useDenylist: true, denylistGenres: ["tango", "vals", "milonga"])
        test("allowlist match is cortina") {
            try expect(d.isCortina(genre: "Cortina"))
        }
        test("denylist match is cortina (Pop not in dance genres)") {
            try expect(d.isCortina(genre: "Pop"))
        }
        test("dance genre is NOT cortina") {
            try expect(!d.isCortina(genre: "Tango"))
        }
    }

    suite("CortinaDetector — Neither rule") {
        let d = CortinaDetector(useAllowlist: false, allowlistGenres: ["cortina"],
                                useDenylist: false, denylistGenres: ["tango"])
        test("never cortina") {
            try expect(!d.isCortina(genre: "Cortina"))
            try expect(!d.isCortina(genre: "Pop"))
            try expect(!d.isCortina(genre: ""))
            try expect(!d.isCortina(genre: "Tango"))
        }
    }

    suite("CortinaDetector — Denylist partial match") {
        let d = CortinaDetector(useAllowlist: false, allowlistGenres: [],
                                useDenylist: true, denylistGenres: ["tango", "vals", "milonga"],
                                denylistPartialGenres: ["tango", "vals", "milonga"])
        test("exact match still not cortina") {
            try expect(!d.isCortina(genre: "Tango"))
            try expect(!d.isCortina(genre: "Vals"))
            try expect(!d.isCortina(genre: "Milonga"))
        }
        test("prefix match with space — not cortina") {
            try expect(!d.isCortina(genre: "Tango Instrumental"))
            try expect(!d.isCortina(genre: "Tango Vocals"))
            try expect(!d.isCortina(genre: "Vals Instrumental"))
            try expect(!d.isCortina(genre: "Milonga Vocal"))
        }
        test("case insensitive prefix match — not cortina") {
            try expect(!d.isCortina(genre: "tango instrumental"))
            try expect(!d.isCortina(genre: "TANGO VOCALS"))
        }
        test("no space after term — is cortina") {
            try expect(d.isCortina(genre: "Tangoed"))
            try expect(d.isCortina(genre: "Valses"))
        }
        test("unrelated genre — is cortina") {
            try expect(d.isCortina(genre: "Pop"))
            try expect(d.isCortina(genre: "Cortina"))
        }

        let noPartial = CortinaDetector(useAllowlist: false, allowlistGenres: [],
                                        useDenylist: true, denylistGenres: ["tango", "vals", "milonga"])
        test("without partial match, Tango Instrumental IS cortina") {
            try expect(noPartial.isCortina(genre: "Tango Instrumental"))
        }
        test("without partial match, exact Tango is still NOT cortina") {
            try expect(!noPartial.isCortina(genre: "Tango"))
        }
    }

    suite("CortinaDetector — Whitespace trimming") {
        let denyOnly = CortinaDetector(useAllowlist: false, allowlistGenres: [],
                                       useDenylist: true, denylistGenres: ["tango", "vals", "milonga"])
        test("leading space on denylist genre is NOT cortina") {
            try expect(!denyOnly.isCortina(genre: " Tango"))
        }
        test("trailing space on denylist genre is NOT cortina") {
            try expect(!denyOnly.isCortina(genre: "Tango "))
        }
        test("leading and trailing spaces is NOT cortina") {
            try expect(!denyOnly.isCortina(genre: "  Tango  "))
        }
        test("tab-padded denylist genre is NOT cortina") {
            try expect(!denyOnly.isCortina(genre: "\tTango"))
        }

        let allowOnly = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                        useDenylist: false, denylistGenres: [])
        test("leading space on allowlist genre IS cortina") {
            try expect(allowOnly.isCortina(genre: " Cortina"))
        }
        test("trailing space on allowlist genre IS cortina") {
            try expect(allowOnly.isCortina(genre: "Cortina "))
        }

        let both = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                   useDenylist: true, denylistGenres: ["tango", "vals", "milonga"])
        test("both rules: spaced Tango is NOT cortina") {
            try expect(!both.isCortina(genre: " Tango"))
        }
        test("both rules: spaced Cortina IS cortina") {
            try expect(both.isCortina(genre: " Cortina"))
        }

        test("spaces-only genre treated as empty -> cortina under denylist") {
            try expect(denyOnly.isCortina(genre: "   "))
        }
    }
}

// MARK: - TandaTracker tests

func runTandaTrackerTests() {
    let tracker = TandaTracker()
    let detector = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                   useDenylist: false, denylistGenres: [])

    func tracks(_ genres: [String]) -> [Track] {
        genres.enumerated().map { i, g in
            Track(title: "T\(i)", artist: "A", genre: g, persistentID: "\(i)")
        }
    }

    suite("TandaTracker — Playlist-based position") {
        test("first track of tanda") {
            // C T T T C
            let t = tracks(["Cortina", "Tango", "Tango", "Tango", "Cortina"])
            let pos = tracker.position(tracks: t, currentIndex: 1, detector: detector)
            try expectEqual(pos?.current, 1)
            try expectEqual(pos?.total, 3)
        }
        test("mid-tanda") {
            let t = tracks(["Cortina", "Tango", "Tango", "Tango", "Cortina"])
            let pos = tracker.position(tracks: t, currentIndex: 2, detector: detector)
            try expectEqual(pos?.current, 2)
            try expectEqual(pos?.total, 3)
        }
        test("last track of tanda") {
            let t = tracks(["Cortina", "Tango", "Tango", "Tango", "Cortina"])
            let pos = tracker.position(tracks: t, currentIndex: 3, detector: detector)
            try expectEqual(pos?.current, 3)
            try expectEqual(pos?.total, 3)
        }
        test("single-track tanda") {
            let t = tracks(["Cortina", "Tango", "Cortina"])
            let pos = tracker.position(tracks: t, currentIndex: 1, detector: detector)
            try expectEqual(pos?.current, 1)
            try expectEqual(pos?.total, 1)
        }
        test("tanda at start of playlist (no leading cortina)") {
            let t = tracks(["Tango", "Tango", "Tango", "Cortina"])
            let pos = tracker.position(tracks: t, currentIndex: 1, detector: detector)
            try expectEqual(pos?.current, 2)
            try expectEqual(pos?.total, 3)
        }
        test("tanda at end of playlist (no trailing cortina)") {
            let t = tracks(["Cortina", "Tango", "Tango", "Tango"])
            let pos = tracker.position(tracks: t, currentIndex: 3, detector: detector)
            try expectEqual(pos?.current, 3)
            try expectEqual(pos?.total, 3)
        }
        test("current is cortina → returns nil") {
            let t = tracks(["Cortina", "Tango"])
            let pos = tracker.position(tracks: t, currentIndex: 0, detector: detector)
            try expectNil(pos)
        }
        test("out of bounds → returns nil") {
            let t = tracks(["Tango"])
            try expectNil(tracker.position(tracks: t, currentIndex: -1, detector: detector))
            try expectNil(tracker.position(tracks: t, currentIndex: 5, detector: detector))
        }
        test("second tanda in playlist") {
            // C T T C T T T C
            let t = tracks(["Cortina", "Tango", "Tango", "Cortina", "Tango", "Tango", "Tango", "Cortina"])
            let pos = tracker.position(tracks: t, currentIndex: 5, detector: detector)
            try expectEqual(pos?.current, 2)
            try expectEqual(pos?.total, 3)
        }
    }

    suite("TandaTracker — History-based position") {
        func h(_ n: Int) -> [Track] {
            (0..<n).map { Track(title: "T\($0)", artist: "A", genre: "Tango", persistentID: "\($0)") }
        }
        test("single track") {
            let pos = tracker.positionFromHistory(h(1))
            try expectEqual(pos?.current, 1)
            try expectNil(pos?.total)
        }
        test("multiple tracks") {
            let pos = tracker.positionFromHistory(h(3))
            try expectEqual(pos?.current, 3)
            try expectNil(pos?.total)
        }
        test("empty history returns nil") {
            try expectNil(tracker.positionFromHistory([]))
        }
    }
}

// MARK: - ProfileStore tests

func runProfileStoreTests() {
    suite("ProfileStore — Round-trip save/load/delete") {
        test("save and reload user profile") {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("TangoDisplayTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let store = ProfileStore(storeURL: tmpDir)
            let profile = AppearanceProfile(
                id: UUID(), name: "Test Profile", isBuiltIn: false,
                backgroundColor: "#FF0000"
            )
            try store.save(profile)

            // Load from disk into a fresh store
            let store2 = ProfileStore(storeURL: tmpDir)
            store2.load()
            try expect(store2.userProfiles.count == 1, "Expected 1 user profile, got \(store2.userProfiles.count)")
            try expectEqual(store2.userProfiles[0].id, profile.id)
            try expectEqual(store2.userProfiles[0].backgroundColor, "#FF0000")
        }

        test("update existing profile") {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("TangoDisplayTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let store = ProfileStore(storeURL: tmpDir)
            var profile = AppearanceProfile(id: UUID(), name: "A", isBuiltIn: false)
            try store.save(profile)
            profile.name = "B"
            try store.save(profile)
            try expectEqual(store.userProfiles.count, 1)
            try expectEqual(store.userProfiles[0].name, "B")
        }

        test("delete user profile") {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("TangoDisplayTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let store = ProfileStore(storeURL: tmpDir)
            let profile = AppearanceProfile(id: UUID(), name: "Del", isBuiltIn: false)
            try store.save(profile)
            try expectEqual(store.userProfiles.count, 1)
            try store.delete(profile)
            try expectEqual(store.userProfiles.count, 0)
            // Verify file is gone
            let fileURL = tmpDir.appendingPathComponent("\(profile.id.uuidString).json")
            try expect(!FileManager.default.fileExists(atPath: fileURL.path), "File should be deleted")
        }

        test("built-in profiles are never written to disk") {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("TangoDisplayTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let store = ProfileStore(storeURL: tmpDir)
            do {
                try store.save(AppearanceProfile.classic)
                try expect(false, "Should have thrown for built-in profile")
            } catch ProfileStoreError.cannotModifyBuiltIn {
                // Expected
            }
            let files = (try? FileManager.default.contentsOfDirectory(atPath: tmpDir.path)) ?? []
            try expect(files.isEmpty, "No files should exist for built-in profile")
        }

        test("delete built-in profile throws") {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("TangoDisplayTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let store = ProfileStore(storeURL: tmpDir)
            do {
                try store.delete(AppearanceProfile.modern)
                try expect(false, "Should have thrown for built-in profile")
            } catch ProfileStoreError.cannotModifyBuiltIn {
                // Expected
            }
        }

        test("allProfiles prepends built-ins") {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("TangoDisplayTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let store = ProfileStore(storeURL: tmpDir)
            let user = AppearanceProfile(id: UUID(), name: "My Profile", isBuiltIn: false)
            try store.save(user)
            let all = store.allProfiles
            try expect(all.count == AppearanceProfile.builtIns.count + 1)
            try expect(all.prefix(AppearanceProfile.builtIns.count)
                          .map(\.id) == AppearanceProfile.builtIns.map(\.id),
                       "Built-ins should come first")
        }
    }
}

// MARK: - DisplayState transition tests (pure logic, no AppKit)

func runDisplayStateTests() {
    // Helper: simulate the core logic that AppState applies
    let detector = CortinaDetector(
        useAllowlist: true, allowlistGenres: ["cortina"],
        useDenylist: true, denylistGenres: ["tango", "vals", "milonga"]
    )
    let tracker = TandaTracker()

    func track(_ title: String, genre: String, pid: String? = nil) -> Track {
        Track(title: title, artist: "A", genre: genre, persistentID: pid ?? title)
    }

    suite("DisplayState — Mode transitions") {
        test("stopped → idle") {
            var state = DisplayState(mode: .playing, currentTrack: track("A", genre: "Tango"))
            // Simulate stopping
            state = DisplayState()
            try expectEqual(state.mode, .idle)
            try expectNil(state.currentTrack)
        }

        test("playing → cortina clears tanda position") {
            var state = DisplayState(mode: .playing,
                                     currentTrack: track("A", genre: "Tango"),
                                     tandaPosition: TandaPosition(current: 2, total: 4))
            let cortina = track("C", genre: "Cortina")
            state = DisplayState(mode: .cortina, currentTrack: cortina)
            try expectEqual(state.mode, .cortina)
            try expectNil(state.tandaPosition)
        }

        test("cortina → playing sets mode correctly") {
            var state = DisplayState(mode: .cortina)
            let tango = track("A", genre: "Tango")
            let pos = tracker.positionFromHistory([tango])
            state = DisplayState(mode: .playing, currentTrack: tango, tandaPosition: pos)
            try expectEqual(state.mode, .playing)
            try expectEqual(state.currentTrack?.genre, "Tango")
            try expectEqual(state.tandaPosition?.current, 1)
        }

        test("override mode ignores track updates") {
            var state = DisplayState(mode: .override, overrideText: "Custom Message")
            // Simulate logic: if mode == .override, don't update
            let newTrack = track("NewTrack", genre: "Tango")
            let shouldUpdate = state.mode != .override
            if shouldUpdate { state.currentTrack = newTrack }
            try expectEqual(state.mode, .override)
            try expect(state.currentTrack == nil, "Override mode should ignore track changes")
            try expectEqual(state.overrideText, "Custom Message")
        }

        test("override cleared returns to idle") {
            var state = DisplayState(mode: .override, overrideText: "Custom")
            state = DisplayState()  // clearOverride resets to idle
            try expectEqual(state.mode, .idle)
            try expectNil(state.overrideText)
        }

        test("empty genre treated as cortina under denylist") {
            let isCortina = detector.isCortina(genre: "")
            try expect(isCortina, "Empty genre should be detected as cortina")
        }

        test("paused mode preserves content") {
            let tango = track("A", genre: "Tango")
            var state = DisplayState(mode: .playing, currentTrack: tango,
                                     tandaPosition: TandaPosition(current: 2, total: 4))
            // Simulate pause: change mode only
            state.mode = .paused
            try expectEqual(state.mode, .paused)
            try expectEqual(state.currentTrack?.title, "A")
            try expectEqual(state.tandaPosition?.current, 2)
        }

        test("next track set during cortina") {
            let cortina = track("C", genre: "Cortina")
            let nextTango = track("Di Sarli", genre: "Tango")
            let state = DisplayState(mode: .cortina, currentTrack: cortina, nextTrack: nextTango)
            try expectEqual(state.mode, .cortina)
            try expectEqual(state.nextTrack?.title, "Di Sarli")
        }

        test("upcoming track uses cortina's real position, not stale index") {
            // Playlist: dance, dance, cortina, dance, dance
            // Simulates the user skipping to the cortina at index 2 while
            // playlistCurrentIndex is stale at 0.
            let tracks: [Track] = [
                track("D1", genre: "Tango",   pid: "d1"),
                track("D2", genre: "Tango",   pid: "d2"),
                track("C1", genre: "Cortina", pid: "c1"),
                track("D3", genre: "Tango",   pid: "d3"),
                track("D4", genre: "Tango",   pid: "d4"),
            ]
            let cortina = tracks[2]

            // Simulate stale index (pointing before the cortina)
            var staleIndex = 0
            // Anchor to real position via persistentID lookup (the fix)
            if let idx = tracks.firstIndex(where: { $0.persistentID == cortina.persistentID }) {
                staleIndex = idx
            }
            // Forward scan from correct position
            let startSearch = staleIndex + 1
            let nextTrack = startSearch < tracks.count
                ? tracks[startSearch...].first { !detector.isCortina(genre: $0.genre) }
                : nil

            try expect(nextTrack?.persistentID == "d3",
                       "Upcoming track should be D3 (after the cortina), not D1")
        }

        test("upcoming track is nil when cortina is last in playlist") {
            let tracks: [Track] = [
                track("D1", genre: "Tango",   pid: "d1"),
                track("C1", genre: "Cortina", pid: "c1"),
            ]
            let cortina = tracks[1]
            var idx = 0
            if let i = tracks.firstIndex(where: { $0.persistentID == cortina.persistentID }) {
                idx = i
            }
            let startSearch = idx + 1
            let nextTrack = startSearch < tracks.count
                ? tracks[startSearch...].first { !detector.isCortina(genre: $0.genre) }
                : nil
            try expect(nextTrack == nil, "No upcoming track when cortina is last in playlist")
        }

        test("playlist-based tanda position during playing") {
            let tracks: [Track] = [
                track("C1", genre: "Cortina", pid: "c1"),
                track("T1", genre: "Tango", pid: "t1"),
                track("T2", genre: "Tango", pid: "t2"),
                track("T3", genre: "Tango", pid: "t3"),
                track("C2", genre: "Cortina", pid: "c2"),
            ]
            let pos = tracker.position(tracks: tracks, currentIndex: 2, detector: detector)
            let state = DisplayState(mode: .playing,
                                     currentTrack: tracks[2],
                                     tandaPosition: pos)
            try expectEqual(state.tandaPosition?.current, 2)
            try expectEqual(state.tandaPosition?.total, 3)
        }
    }
}

// MARK: - ReplayGain tests

func runReplayGainTests() {
    suite("parseReplayGainDb") {
        test("parses negative dB with unit") {
            try expectEqual(parseReplayGainDb("-7.23 dB"), -7.23)
        }
        test("parses positive dB with unit") {
            try expectEqual(parseReplayGainDb("+3.00 dB"), 3.0)
        }
        test("parses negative dB without unit") {
            try expectEqual(parseReplayGainDb("-5.4"), -5.4)
        }
        test("parses value with uppercase DB") {
            try expectEqual(parseReplayGainDb("-2.0 DB"), -2.0)
        }
        test("returns nil for non-numeric") {
            try expectNil(parseReplayGainDb("abc dB"))
        }
        test("returns nil for nil input") {
            try expectNil(parseReplayGainDb(nil))
        }
        test("returns nil for empty string") {
            try expectNil(parseReplayGainDb(""))
        }
    }

    suite("calculateReplayGainLinear — mode off") {
        test("always returns 1.0 when mode is off") {
            let info = ReplayGainInfo(trackGainDb: -7.0, trackPeak: 0.95, albumGainDb: -6.0, albumPeak: 0.90)
            let settings = ReplayGainSettings(mode: .off, preampDb: 0, preventClipping: false)
            try expectEqual(calculateReplayGainLinear(info: info, settings: settings), 1.0)
        }
        test("returns 1.0 when mode is off and info is nil") {
            let settings = ReplayGainSettings(mode: .off, preampDb: 0, preventClipping: false)
            try expectEqual(calculateReplayGainLinear(info: nil, settings: settings), 1.0)
        }
    }

    suite("calculateReplayGainLinear — track gain mode") {
        test("applies track gain correctly") {
            let info = ReplayGainInfo(trackGainDb: -6.0206, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: false)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            // -6.0206 dB ≈ 0.5 linear
            try expect(abs(gain - 0.5) < 0.001, "Expected ~0.5, got \(gain)")
        }
        test("returns 1.0 when track gain is missing") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: 0.95, albumGainDb: -5.0, albumPeak: 0.90)
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: false)
            try expectEqual(calculateReplayGainLinear(info: info, settings: settings), 1.0)
        }
        test("returns 1.0 when info is nil") {
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: false)
            try expectEqual(calculateReplayGainLinear(info: nil, settings: settings), 1.0)
        }
        test("returns 1.0 when all fields are nil") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: false)
            try expectEqual(calculateReplayGainLinear(info: info, settings: settings), 1.0)
        }
    }

    suite("calculateReplayGainLinear — album gain mode") {
        test("applies album gain correctly") {
            let info = ReplayGainInfo(trackGainDb: -7.0, trackPeak: 0.95, albumGainDb: -5.0, albumPeak: 0.90)
            let settings = ReplayGainSettings(mode: .album, preampDb: 0, preventClipping: false)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            let expected = Float(pow(10.0, -5.0 / 20.0))
            try expect(abs(gain - expected) < 0.0001, "Expected \(expected), got \(gain)")
        }
        test("returns 1.0 when album gain is missing even if track gain is present") {
            let info = ReplayGainInfo(trackGainDb: -7.0, trackPeak: 0.95, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .album, preampDb: 0, preventClipping: false)
            try expectEqual(calculateReplayGainLinear(info: info, settings: settings), 1.0)
        }
    }

    suite("calculateReplayGainLinear — preamp") {
        test("adds preamp dB to gain") {
            let info = ReplayGainInfo(trackGainDb: 0.0, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: 6.0, preventClipping: false)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            let expected = Float(pow(10.0, 6.0 / 20.0))
            try expect(abs(gain - expected) < 0.0001, "Expected \(expected), got \(gain)")
        }
        test("negative preamp reduces gain") {
            let info = ReplayGainInfo(trackGainDb: 0.0, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: -6.0, preventClipping: false)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            let expected = Float(pow(10.0, -6.0 / 20.0))
            try expect(abs(gain - expected) < 0.0001, "Expected \(expected), got \(gain)")
        }
    }

    suite("calculateReplayGainLinear — clipping protection") {
        test("reduces gain when gain * peak exceeds 1.0") {
            // +4 dB gain with peak 0.90 → linear ≈ 1.585 * 0.90 > 1.0, should clamp to 1/0.90
            let info = ReplayGainInfo(trackGainDb: 4.0, trackPeak: 0.90, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: true)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            let maxGain = Float(1.0 / 0.90)
            try expect(abs(gain - maxGain) < 0.0001, "Expected \(maxGain), got \(gain)")
        }
        test("does not reduce gain when clipping protection is off") {
            let info = ReplayGainInfo(trackGainDb: 4.0, trackPeak: 0.90, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: false)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            let expected = Float(pow(10.0, 4.0 / 20.0))
            try expect(abs(gain - expected) < 0.0001, "Expected \(expected), got \(gain)")
        }
        test("no clipping reduction needed when gain * peak is within 1.0") {
            // -7.23 dB gain with peak 0.95 → linear ≈ 0.436 * 0.95 < 1.0, no clamping
            let info = ReplayGainInfo(trackGainDb: -7.23, trackPeak: 0.95, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: true)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            let expected = Float(pow(10.0, -7.23 / 20.0))
            try expect(abs(gain - expected) < 0.0001, "Expected \(expected), got \(gain)")
        }
        test("skips clipping check when peak is nil") {
            let info = ReplayGainInfo(trackGainDb: 4.0, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let settings = ReplayGainSettings(mode: .track, preampDb: 0, preventClipping: true)
            let gain = calculateReplayGainLinear(info: info, settings: settings)
            let expected = Float(pow(10.0, 4.0 / 20.0))
            try expect(abs(gain - expected) < 0.0001, "Expected \(expected), got \(gain)")
        }
    }
}

// MARK: - Auto ReplayGain tests

func runAutoReplayGainTests() {

    // MARK: Helpers

    func makeAnalysis(gainDb: Double, lufs: Double, samplePeak: Double? = nil,
                      truePeak: Double? = nil) -> LoudnessAnalysisResult {
        LoudnessAnalysisResult(
            filePath: "/fake/track.flac", fileSize: 1_000_000,
            modifiedDate: Date(), duration: 180,
            integratedLoudnessLufs: lufs, calculatedReplayGainDb: gainDb,
            targetLoudnessLufs: -18.0,
            samplePeak: samplePeak, truePeak: truePeak, analysedAt: Date())
    }

    func baseSettings(mode: ReplayGainMode, preventClipping: Bool = false,
                       preamp: Double = 0) -> ReplayGainSettings {
        ReplayGainSettings(mode: mode, preampDb: preamp,
                           preventClipping: preventClipping, targetLoudnessLufs: -18.0)
    }

    // MARK: calculateReplayGain — auto mode

    suite("calculateReplayGain — auto mode") {
        test("uses track metadata when present, ignores analysis") {
            let info = ReplayGainInfo(trackGainDb: -7.0, trackPeak: nil, albumGainDb: -5.0, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: -3.0, lufs: -15.0)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .auto))
            try expectEqual(result.source, .metadataTrack)
            let expected = Float(pow(10.0, -7.0 / 20.0))
            try expect(abs(result.linearGain - expected) < 0.0001,
                       "Expected ~\(expected), got \(result.linearGain)")
        }

        test("uses analysis when track metadata is absent") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: -7.1, lufs: -10.9)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .auto))
            try expectEqual(result.source, .analysed)
            let expected = Float(pow(10.0, -7.1 / 20.0))
            try expect(abs(result.linearGain - expected) < 0.0001,
                       "Expected ~\(expected), got \(result.linearGain)")
        }

        test("does not use album metadata in auto mode") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: -5.0, albumPeak: nil)
            let result = calculateReplayGain(info: info, analysis: nil,
                                              settings: baseSettings(mode: .auto))
            try expectEqual(result.source, .none)
            try expectEqual(result.linearGain, 1.0)
        }

        test("returns 1.0 when neither metadata nor analysis present") {
            let result = calculateReplayGain(info: nil, analysis: nil,
                                              settings: baseSettings(mode: .auto))
            try expectEqual(result.source, .none)
            try expectEqual(result.linearGain, 1.0)
        }

        test("integratedLoudnessLufs populated for analysed source") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: -7.1, lufs: -10.9)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .auto))
            try expect(result.integratedLoudnessLufs != nil, "Expected integratedLoudnessLufs to be set")
            try expect(abs(result.integratedLoudnessLufs! - (-10.9)) < 0.001,
                       "Expected -10.9, got \(result.integratedLoudnessLufs!)")
        }

        test("integratedLoudnessLufs is nil for metadata source") {
            let info = ReplayGainInfo(trackGainDb: -7.0, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let result = calculateReplayGain(info: info, analysis: nil,
                                              settings: baseSettings(mode: .auto))
            try expectNil(result.integratedLoudnessLufs)
        }
    }

    // MARK: calculateReplayGain — mode isolation

    suite("calculateReplayGain — mode isolation") {
        test("track mode ignores analysis") {
            let info = ReplayGainInfo(trackGainDb: -7.0, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: -3.0, lufs: -15.0)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .track))
            try expectEqual(result.source, .metadataTrack)
        }

        test("album mode ignores analysis") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: -5.0, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: -3.0, lufs: -15.0)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .album))
            try expectEqual(result.source, .metadataAlbum)
        }

        test("off mode ignores metadata and analysis") {
            let info = ReplayGainInfo(trackGainDb: -7.0, trackPeak: nil, albumGainDb: -5.0, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: -3.0, lufs: -15.0)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .off))
            try expectEqual(result.source, .none)
            try expectEqual(result.linearGain, 1.0)
        }
    }

    // MARK: calculateReplayGain — preamp with analysis

    suite("calculateReplayGain — preamp with analysed gain") {
        test("preamp applies to analysed gain") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: -7.0, lufs: -11.0)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .auto, preamp: 2.0))
            let expected = Float(pow(10.0, (-7.0 + 2.0) / 20.0))
            try expect(abs(result.linearGain - expected) < 0.0001,
                       "Expected ~\(expected), got \(result.linearGain)")
        }
    }

    // MARK: calculateReplayGain — clipping with analysis peaks

    suite("calculateReplayGain — clipping protection with analysed peaks") {
        test("uses samplePeak for clipping protection") {
            // gain +4 dB * samplePeak 0.90 > 1.0 → clamp to 1/0.90
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: 4.0, lufs: -22.0, samplePeak: 0.90)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .auto, preventClipping: true))
            let maxGain = Float(1.0 / 0.90)
            try expect(result.clippingProtectionApplied, "Expected clipping protection to be applied")
            try expect(abs(result.linearGain - maxGain) < 0.0001,
                       "Expected \(maxGain), got \(result.linearGain)")
        }

        test("prefers truePeak over samplePeak when both present") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            // truePeak is lower than samplePeak → truePeak is the binding constraint
            let analysis = makeAnalysis(gainDb: 4.0, lufs: -22.0, samplePeak: 0.90, truePeak: 0.85)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .auto, preventClipping: true))
            let maxGain = Float(1.0 / 0.85)
            try expect(result.clippingProtectionApplied, "Expected clipping protection to be applied")
            try expect(abs(result.linearGain - maxGain) < 0.0001,
                       "Expected \(maxGain) (truePeak), got \(result.linearGain)")
        }

        test("clipping off — full gain applied even when would clip") {
            let info = ReplayGainInfo(trackGainDb: nil, trackPeak: nil, albumGainDb: nil, albumPeak: nil)
            let analysis = makeAnalysis(gainDb: 4.0, lufs: -22.0, samplePeak: 0.90)
            let result = calculateReplayGain(info: info, analysis: analysis,
                                              settings: baseSettings(mode: .auto, preventClipping: false))
            let expected = Float(pow(10.0, 4.0 / 20.0))
            try expect(!result.clippingProtectionApplied, "Expected no clipping protection")
            try expect(abs(result.linearGain - expected) < 0.0001,
                       "Expected \(expected), got \(result.linearGain)")
        }
    }

    // MARK: LoudnessAnalysisCacheKey equality

    suite("LoudnessAnalysisCacheKey — equality (path + size + modDate only)") {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let key = LoudnessAnalysisCacheKey(filePath: "/music/track.flac",
                                            fileSize: 10_000_000,
                                            modifiedDate: date)

        test("identical keys are equal") {
            let key2 = LoudnessAnalysisCacheKey(filePath: "/music/track.flac",
                                                 fileSize: 10_000_000,
                                                 modifiedDate: date)
            try expect(key == key2, "Keys with same fields should be equal")
        }

        test("mismatch on fileSize") {
            let key2 = LoudnessAnalysisCacheKey(filePath: "/music/track.flac",
                                                 fileSize: 9_999_999,
                                                 modifiedDate: date)
            try expect(key != key2, "Keys should differ when fileSize changes")
        }

        test("mismatch on modifiedDate") {
            let key2 = LoudnessAnalysisCacheKey(filePath: "/music/track.flac",
                                                 fileSize: 10_000_000,
                                                 modifiedDate: Date(timeIntervalSince1970: 1_700_000_001))
            try expect(key != key2, "Keys should differ when modifiedDate changes")
        }

        test("duration variation does not affect key — prevents spurious cache misses") {
            // AVAudioFile may report slightly different frame counts across codec versions.
            // Cache key must be stable regardless of decoded duration precision.
            let k1 = LoudnessAnalysisCacheKey(filePath: "/music/a.m4a",
                                               fileSize: 5_000_000,
                                               modifiedDate: date)
            let k2 = LoudnessAnalysisCacheKey(filePath: "/music/a.m4a",
                                               fileSize: 5_000_000,
                                               modifiedDate: date)
            try expect(k1 == k2, "Keys must be equal regardless of any duration value")
        }

        test("mismatch on filePath") {
            let key2 = LoudnessAnalysisCacheKey(filePath: "/music/other.flac",
                                                 fileSize: 10_000_000,
                                                 modifiedDate: date)
            try expect(key != key2, "Keys should differ when filePath changes")
        }
    }
}

// MARK: - AudioUnitPlugin tests

func runAudioUnitPluginTests() {
    suite("AudioUnitPluginSelection — model") {
        test("encodes and decodes round-trip") {
            let sel = AudioUnitPluginSelection(
                id: UUID(),
                name: "Test EQ",
                manufacturerName: "Acme Audio",
                componentType: 1635083896,
                componentSubType: 1162298982,
                componentManufacturer: 1634758764
            )
            let data = try JSONEncoder().encode(sel)
            let decoded = try JSONDecoder().decode(AudioUnitPluginSelection.self, from: data)
            try expectEqual(decoded.name, sel.name)
            try expectEqual(decoded.manufacturerName, sel.manufacturerName)
            try expectEqual(decoded.componentType, sel.componentType)
            try expectEqual(decoded.componentSubType, sel.componentSubType)
            try expectEqual(decoded.componentManufacturer, sel.componentManufacturer)
            try expectEqual(decoded.id, sel.id)
        }

        test("reconstructs component values from stored data") {
            let type: UInt32 = 1635083896
            let sub: UInt32  = 9999
            let mfr: UInt32  = 1634758764
            let sel = AudioUnitPluginSelection(
                name: "FX", manufacturerName: "Co",
                componentType: type, componentSubType: sub, componentManufacturer: mfr
            )
            let data = try JSONEncoder().encode(sel)
            let out = try JSONDecoder().decode(AudioUnitPluginSelection.self, from: data)
            try expectEqual(out.componentType, type)
            try expectEqual(out.componentSubType, sub)
            try expectEqual(out.componentManufacturer, mfr)
        }

        test("invalid JSON decodes safely to nil") {
            let bad = "not json".data(using: .utf8)!
            let result = try? JSONDecoder().decode(AudioUnitPluginSelection.self, from: bad)
            try expectNil(result)
        }

        test("Equatable — identical values are equal") {
            let id = UUID()
            let a = AudioUnitPluginSelection(id: id, name: "X", manufacturerName: "Y",
                                             componentType: 1, componentSubType: 2, componentManufacturer: 3)
            let b = AudioUnitPluginSelection(id: id, name: "X", manufacturerName: "Y",
                                             componentType: 1, componentSubType: 2, componentManufacturer: 3)
            try expect(a == b)
        }

        test("Equatable — different id is not equal") {
            let a = AudioUnitPluginSelection(name: "X", manufacturerName: "Y",
                                             componentType: 1, componentSubType: 2, componentManufacturer: 3)
            let b = AudioUnitPluginSelection(name: "X", manufacturerName: "Y",
                                             componentType: 1, componentSubType: 2, componentManufacturer: 3)
            try expect(a != b)
        }
    }

    suite("AudioUnitPluginStatus — display text") {
        test("disabled") {
            try expectEqual(AudioUnitPluginStatus.disabled.displayText, "Plugin: Disabled")
        }
        test("noPluginSelected") {
            try expectEqual(AudioUnitPluginStatus.noPluginSelected.displayText, "Plugin: No plugin selected")
        }
        test("loading") {
            try expectEqual(AudioUnitPluginStatus.loading("Focusrite Red 2 EQ").displayText,
                            "Plugin: Loading Focusrite Red 2 EQ…")
        }
        test("active") {
            try expectEqual(AudioUnitPluginStatus.active("MJUC").displayText, "Plugin: Active — MJUC")
        }
        test("bypassed") {
            try expectEqual(AudioUnitPluginStatus.bypassed("MJUC").displayText, "Plugin: Bypassed — MJUC")
        }
        test("unavailable") {
            try expectEqual(AudioUnitPluginStatus.unavailable("Focusrite Red 2 EQ").displayText,
                            "Plugin: Not available — Focusrite Red 2 EQ")
        }
        test("failed") {
            try expectEqual(AudioUnitPluginStatus.failed("REAMP", reason: "timeout").displayText,
                            "Plugin: Failed to load — REAMP")
        }
    }

    suite("AudioUnitPluginStatus — predicates") {
        test("isActive true only for active") {
            try expect(AudioUnitPluginStatus.active("X").isActive)
            try expect(!AudioUnitPluginStatus.disabled.isActive)
            try expect(!AudioUnitPluginStatus.loading("X").isActive)
            try expect(!AudioUnitPluginStatus.bypassed("X").isActive)
            try expect(!AudioUnitPluginStatus.failed("X", reason: "r").isActive)
        }
        test("isInert true for disabled and noPluginSelected") {
            try expect(AudioUnitPluginStatus.disabled.isInert)
            try expect(AudioUnitPluginStatus.noPluginSelected.isInert)
            try expect(!AudioUnitPluginStatus.active("X").isInert)
            try expect(!AudioUnitPluginStatus.loading("X").isInert)
            try expect(!AudioUnitPluginStatus.bypassed("X").isInert)
            try expect(!AudioUnitPluginStatus.unavailable("X").isInert)
            try expect(!AudioUnitPluginStatus.failed("X", reason: "r").isInert)
        }
        test("shortDisplayText empty for inert statuses") {
            try expectEqual(AudioUnitPluginStatus.disabled.shortDisplayText, "")
            try expectEqual(AudioUnitPluginStatus.noPluginSelected.shortDisplayText, "")
        }
        test("shortDisplayText non-empty for active statuses") {
            try expect(!AudioUnitPluginStatus.active("MJUC").shortDisplayText.isEmpty)
            try expect(!AudioUnitPluginStatus.bypassed("MJUC").shortDisplayText.isEmpty)
            try expect(!AudioUnitPluginStatus.loading("MJUC").shortDisplayText.isEmpty)
        }
        test("Equatable — same cases are equal") {
            try expect(AudioUnitPluginStatus.active("X") == AudioUnitPluginStatus.active("X"))
            try expect(AudioUnitPluginStatus.disabled == AudioUnitPluginStatus.disabled)
        }
        test("Equatable — different cases are not equal") {
            try expect(AudioUnitPluginStatus.active("X") != AudioUnitPluginStatus.bypassed("X"))
            try expect(AudioUnitPluginStatus.failed("X", reason: "a") != AudioUnitPluginStatus.failed("X", reason: "b"))
        }
    }
}

// MARK: - TandaPosition label tests

func runTandaPositionTests() {
    suite("TandaPosition — label") {
        test("with total") {
            try expectEqual(TandaPosition(current: 2, total: 4).label, "Track 2 of 4")
        }
        test("without total") {
            try expectEqual(TandaPosition(current: 3, total: nil).label, "Track 3")
        }
    }
}

// MARK: - AudioUnitPreset tests

func runAudioUnitPresetTests() {
    suite("AudioUnitPreset — kind predicates") {
        test("factory preset") {
            let p = AudioUnitPreset(name: "Hall", kind: .factory(number: 3))
            try expect(p.isFactory)
            try expect(!p.isUser)
            try expectEqual(p.factoryNumber, 3)
        }
        test("user preset") {
            let p = AudioUnitPreset(name: "Mine", kind: .user(parameterData: Data([1, 2, 3])))
            try expect(!p.isFactory)
            try expect(p.isUser)
            try expectNil(p.factoryNumber)
        }
        test("explicit id is retained") {
            let id = UUID()
            let p = AudioUnitPreset(id: id, name: "X", kind: .factory(number: 0))
            try expectEqual(p.id, id)
        }
        test("Equatable — same kind & id are equal") {
            let id = UUID()
            try expect(AudioUnitPreset(id: id, name: "A", kind: .factory(number: 1))
                       == AudioUnitPreset(id: id, name: "A", kind: .factory(number: 1)))
        }
    }
}

// MARK: - AudioUnitPluginStatus shortDisplayText (exact strings)

func runAudioUnitPluginStatusShortTextTests() {
    suite("AudioUnitPluginStatus — shortDisplayText exact") {
        test("loading") {
            try expectEqual(AudioUnitPluginStatus.loading("MJUC").shortDisplayText, "AU: Loading MJUC…")
        }
        test("active") {
            try expectEqual(AudioUnitPluginStatus.active("MJUC").shortDisplayText, "AU: MJUC")
        }
        test("bypassed (name omitted)") {
            try expectEqual(AudioUnitPluginStatus.bypassed("MJUC").shortDisplayText, "AU: Bypassed")
        }
        test("unavailable") {
            try expectEqual(AudioUnitPluginStatus.unavailable("Red 2 EQ").shortDisplayText,
                            "AU: Not available — Red 2 EQ")
        }
        test("failed (reason omitted)") {
            try expectEqual(AudioUnitPluginStatus.failed("REAMP", reason: "timeout").shortDisplayText,
                            "AU: Failed to load")
        }
    }
}

// MARK: - ReplayGainMode tests

func runReplayGainModeTests() {
    suite("ReplayGainMode — displayName & coding") {
        test("display names") {
            try expectEqual(ReplayGainMode.off.displayName, "Off")
            try expectEqual(ReplayGainMode.track.displayName, "Track Gain")
            try expectEqual(ReplayGainMode.album.displayName, "Album Gain")
            try expectEqual(ReplayGainMode.auto.displayName, "Auto")
        }
        test("id equals rawValue") {
            try expectEqual(ReplayGainMode.auto.id, "auto")
        }
        test("rawValues are stable") {
            try expectEqual(ReplayGainMode.allCases.map(\.rawValue), ["off", "track", "album", "auto"])
        }
        test("codable round-trip for all cases") {
            for mode in ReplayGainMode.allCases {
                let data = try JSONEncoder().encode([mode])
                let back = try JSONDecoder().decode([ReplayGainMode].self, from: data)
                try expectEqual(back, [mode])
            }
        }
    }
}

// MARK: - LoudnessAnalysisResult tests

func runLoudnessAnalysisResultTests() {
    let modDate = Date(timeIntervalSince1970: 1_700_000_000)
    let analysedAt = Date(timeIntervalSince1970: 1_700_000_500)
    func make() -> LoudnessAnalysisResult {
        LoudnessAnalysisResult(
            filePath: "/music/a.flac", fileSize: 4242, modifiedDate: modDate,
            duration: 180, integratedLoudnessLufs: -12.5, calculatedReplayGainDb: -5.5,
            targetLoudnessLufs: -18.0, samplePeak: 0.9, truePeak: 0.95, analysedAt: analysedAt)
    }
    suite("LoudnessAnalysisResult — cacheKey & coding") {
        test("cacheKey derives path/size/modDate") {
            let k = make().cacheKey
            try expectEqual(k.filePath, "/music/a.flac")
            try expectEqual(k.fileSize, 4242)
            try expectEqual(k.modifiedDate, modDate)
        }
        test("cacheKey equals a freshly built key") {
            try expect(make().cacheKey == LoudnessAnalysisCacheKey(
                filePath: "/music/a.flac", fileSize: 4242, modifiedDate: modDate))
        }
        test("codable round-trip") {
            let r = make()
            let data = try JSONEncoder().encode(r)
            let back = try JSONDecoder().decode(LoudnessAnalysisResult.self, from: data)
            try expectEqual(back, r)
        }
    }
}

// MARK: - Codable model round-trips (Track, ReplayGainInfo)

func runCodableModelTests() {
    suite("Track — codable & hashable") {
        test("round-trip with all fields") {
            let rg = ReplayGainInfo(trackGainDb: -7.0, trackPeak: 0.9, albumGainDb: -6.0, albumPeak: 0.88)
            let t = Track(title: "A", artist: "B", genre: "Tango", persistentID: "pid",
                          year: 1947, comment: "c", albumArtist: "aa", grouping: "g", replayGainInfo: rg)
            let data = try JSONEncoder().encode(t)
            let back = try JSONDecoder().decode(Track.self, from: data)
            try expectEqual(back, t)
            try expectEqual(back.replayGainInfo, rg)
        }
        test("round-trip with nil optionals") {
            let t = Track(title: "A", artist: "B", genre: "", persistentID: "pid")
            let data = try JSONEncoder().encode(t)
            let back = try JSONDecoder().decode(Track.self, from: data)
            try expectEqual(back, t)
            try expectNil(back.year)
            try expectNil(back.replayGainInfo)
        }
        test("hashable — equal tracks collide in a Set") {
            let t1 = Track(title: "A", artist: "B", genre: "T", persistentID: "1")
            let t2 = Track(title: "A", artist: "B", genre: "T", persistentID: "1")
            try expect(Set([t1]).contains(t2))
        }
    }
    suite("ReplayGainInfo — codable") {
        test("round-trip preserves nils") {
            let rg = ReplayGainInfo(trackGainDb: -7.0, trackPeak: nil, albumGainDb: nil, albumPeak: 0.5)
            let data = try JSONEncoder().encode(rg)
            let back = try JSONDecoder().decode(ReplayGainInfo.self, from: data)
            try expectEqual(back, rg)
        }
    }
}

// MARK: - Enum displayName / coding tests

func runEnumDisplayTests() {
    suite("DisplayTextItem — displayName & coding") {
        test("representative display names") {
            try expectEqual(DisplayTextItem.genre.displayName, "Genre")
            try expectEqual(DisplayTextItem.trackCounter.displayName, "Track Counter")
            try expectEqual(DisplayTextItem.nextUpLabel.displayName, "Next Up Label")
            try expectEqual(DisplayTextItem.lastTandaLabel.displayName, "Last Tanda Label")
        }
        test("rawValue codable round-trip for all cases") {
            for item in DisplayTextItem.allCases {
                let data = try JSONEncoder().encode([item])
                let back = try JSONDecoder().decode([DisplayTextItem].self, from: data)
                try expectEqual(back, [item])
            }
        }
    }
    suite("SingerSource — displayName & rawValue") {
        test("display names") {
            try expectEqual(SingerSource.comments.displayName, "Comments")
            try expectEqual(SingerSource.albumArtist.displayName, "Album Artist")
            try expectEqual(SingerSource.grouping.displayName, "Grouping")
        }
        test("rawValues stable") {
            try expectEqual(SingerSource.albumArtist.rawValue, "albumArtist")
        }
    }
    suite("TransitionStyle — displayName") {
        test("display names") {
            try expectEqual(TransitionStyle.fade.displayName, "Crossfade")
            try expectEqual(TransitionStyle.cut.displayName, "Hard Cut")
            try expectEqual(TransitionStyle.fadeToBlack.displayName, "Fade Through Black")
            try expectEqual(TransitionStyle.push.displayName, "Push")
            try expectEqual(TransitionStyle.zoom.displayName, "Zoom")
        }
    }
    suite("GenreBackground — isCortinaEntry") {
        test("empty genreKey is the cortina sentinel") {
            try expect(GenreBackground(genreKey: "").isCortinaEntry)
        }
        test("non-empty genreKey is not the sentinel") {
            try expect(!GenreBackground(genreKey: "tango").isCortinaEntry)
        }
    }
}

// MARK: - AppearanceProfile matching logic tests

func runAppearanceProfileMatchingTests() {
    func profile(_ mutate: (inout AppearanceProfile) -> Void) -> AppearanceProfile {
        var p = AppearanceProfile(id: UUID(), name: "P", isBuiltIn: false)
        mutate(&p)
        return p
    }
    func track(artist: String = "A", genre: String = "Tango",
               comment: String? = nil, albumArtist: String? = nil, grouping: String? = nil) -> Track {
        Track(title: "T", artist: artist, genre: genre, persistentID: "1",
              comment: comment, albumArtist: albumArtist, grouping: grouping)
    }

    suite("AppearanceProfile — singerValue") {
        test("comments source") {
            let p = profile { $0.singerSource = .comments }
            try expectEqual(p.singerValue(from: track(comment: "Echániz")), "Echániz")
        }
        test("albumArtist source") {
            let p = profile { $0.singerSource = .albumArtist }
            try expectEqual(p.singerValue(from: track(albumArtist: "Di Sarli")), "Di Sarli")
        }
        test("grouping source") {
            let p = profile { $0.singerSource = .grouping }
            try expectEqual(p.singerValue(from: track(grouping: "Vocal")), "Vocal")
        }
        test("nil when chosen field is absent") {
            let p = profile { $0.singerSource = .comments }
            try expectNil(p.singerValue(from: track(comment: nil)))
        }
    }

    suite("AppearanceProfile — matchingArtistBackground") {
        let bg = ArtistBackground(artistName: "Di Sarli", imageFilename: "artist-1.jpg")
        test("disabled returns nil") {
            let p = profile { $0.artistBackgroundsEnabled = false; $0.artistBackgrounds = [bg] }
            try expectNil(p.matchingArtistBackground(for: "Carlos Di Sarli"))
        }
        test("partial, case-insensitive match") {
            let p = profile { $0.artistBackgroundsEnabled = true; $0.artistBackgrounds = [bg] }
            try expect(p.matchingArtistBackground(for: "Orquesta Carlos Di Sarli")?.id == bg.id)
            try expect(p.matchingArtistBackground(for: "di sarli")?.id == bg.id)
        }
        test("diacritic-insensitive match") {
            let angel = ArtistBackground(artistName: "Angel", imageFilename: "a.jpg")
            let p = profile { $0.artistBackgroundsEnabled = true; $0.artistBackgrounds = [angel] }
            try expect(p.matchingArtistBackground(for: "Ángel D'Agostino")?.id == angel.id)
        }
        test("no match returns nil") {
            let p = profile { $0.artistBackgroundsEnabled = true; $0.artistBackgrounds = [bg] }
            try expectNil(p.matchingArtistBackground(for: "Pugliese"))
        }
        test("empty entry name is skipped") {
            let empty = ArtistBackground(artistName: "", imageFilename: "x.jpg")
            let p = profile { $0.artistBackgroundsEnabled = true; $0.artistBackgrounds = [empty] }
            try expectNil(p.matchingArtistBackground(for: "Anything"))
        }
    }

    suite("AppearanceProfile — matchingGenreBackground") {
        let detector = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                       useDenylist: true, denylistGenres: ["tango", "vals", "milonga"],
                                       denylistPartialGenres: ["tango", "vals", "milonga"])
        let tangoBg = GenreBackground(genreKey: "Tango", imageFilename: "g-tango.jpg")
        let cortinaBg = GenreBackground(genreKey: "", imageFilename: "g-cortina.jpg")

        test("disabled returns nil") {
            let p = profile { $0.genreBackgroundsEnabled = false; $0.genreBackgrounds = [tangoBg] }
            try expectNil(p.matchingGenreBackground(for: "Tango", using: detector))
        }
        test("cortina genre returns the sentinel entry") {
            let p = profile { $0.genreBackgroundsEnabled = true; $0.genreBackgrounds = [tangoBg, cortinaBg] }
            try expect(p.matchingGenreBackground(for: "Cortina", using: detector)?.id == cortinaBg.id)
        }
        test("cortina sentinel without an image returns nil") {
            let noImg = GenreBackground(genreKey: "", imageFilename: nil)
            let p = profile { $0.genreBackgroundsEnabled = true; $0.genreBackgrounds = [noImg] }
            try expectNil(p.matchingGenreBackground(for: "Cortina", using: detector))
        }
        test("exact case-insensitive genre match") {
            let p = profile { $0.genreBackgroundsEnabled = true; $0.genreBackgrounds = [tangoBg] }
            try expect(p.matchingGenreBackground(for: "tango", using: detector)?.id == tangoBg.id)
        }
        test("word-boundary partial match when key is in the partial set") {
            let p = profile { $0.genreBackgroundsEnabled = true; $0.genreBackgrounds = [tangoBg] }
            try expect(p.matchingGenreBackground(for: "Tango Instrumental", using: detector)?.id == tangoBg.id)
        }
        test("entry without an image is skipped") {
            let noImg = GenreBackground(genreKey: "Tango", imageFilename: nil)
            let p = profile { $0.genreBackgroundsEnabled = true; $0.genreBackgrounds = [noImg] }
            try expectNil(p.matchingGenreBackground(for: "Tango", using: detector))
        }
        test("empty genre returns nil on the non-cortina path") {
            let allowOnly = CortinaDetector(useAllowlist: true, allowlistGenres: ["cortina"],
                                            useDenylist: false, denylistGenres: [])
            let p = profile { $0.genreBackgroundsEnabled = true; $0.genreBackgrounds = [tangoBg] }
            try expectNil(p.matchingGenreBackground(for: "", using: allowOnly))
        }
    }
}

// MARK: - AppearanceProfile decoding / migration tests

func runAppearanceProfileMigrationTests() {
    func decode(_ json: String) throws -> AppearanceProfile {
        try JSONDecoder().decode(AppearanceProfile.self, from: Data(json.utf8))
    }

    // Minimal legacy JSON: only the keys the decoder requires via plain `decode`.
    let minimalJSON = """
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Legacy", "isBuiltIn": false,
      "titleFontName": "System", "titleFontSize": 72,
      "artistFontName": "System", "artistFontSize": 96,
      "genreFontName": "System", "genreFontSize": 36,
      "backgroundColor": "#000000",
      "titleColor": "#FFFFFF", "artistColor": "#EEEEEE", "genreColor": "#AAAAAA",
      "transitionStyle": "fade", "transitionDuration": 0.4
    }
    """

    // Legacy JSON carrying the old aggregate visibility flags but none of the per-type ones.
    let legacyFlagsJSON = """
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "name": "LegacyFlags", "isBuiltIn": false,
      "titleFontName": "System", "titleFontSize": 72,
      "artistFontName": "System", "artistFontSize": 96,
      "genreFontName": "System", "genreFontSize": 36,
      "backgroundColor": "#000000",
      "titleColor": "#FFFFFF", "artistColor": "#EEEEEE", "genreColor": "#AAAAAA",
      "transitionStyle": "fade", "transitionDuration": 0.4,
      "showYear": true, "showSinger": true, "showAlbumArtwork": true
    }
    """

    suite("AppearanceProfile — decoding defaults") {
        test("missing optional keys fall back to defaults") {
            let p = try decode(minimalJSON)
            try expect(!p.showYear)
            try expectEqual(p.yearColor, "#AAAAAA")
            try expectEqual(p.trackCounterColor, "#AAAAAA")
            try expectEqual(p.singerSource, .comments)
            try expect(p.showLastTandaLabel)
            try expectEqual(p.transitionStyle, .fade)
        }
        test("colour fallbacks reference base colours") {
            let p = try decode(minimalJSON)
            try expectEqual(p.cortinaLabelColor, "#EEEEEE")   // ← artistColor
            try expectEqual(p.nextUpLabelColor, "#AAAAAA")    // ← genreColor
            try expectEqual(p.idleMessageColor, "#EEEEEE")    // ← artistColor
            try expectEqual(p.overrideTextColor, "#FFFFFF")   // ← titleColor
            try expectEqual(p.cortinaLabelFontName, "System") // ← titleFontName
        }
    }

    suite("AppearanceProfile — order-list migration") {
        test("dance order gains lastTandaLabel and trackCounter") {
            let p = try decode(minimalJSON)
            try expect(p.danceItemOrder.contains(.lastTandaLabel))
            try expect(p.danceItemOrder.contains(.trackCounter))
        }
        test("cortina order gains nextUpLabel (front), title, and lastTandaLabel") {
            let p = try decode(minimalJSON)
            try expectEqual(p.cortinaItemOrder,
                            [.nextUpLabel, .genre, .artist, .year, .title, .singer, .lastTandaLabel, .lastPlayed])
        }
    }

    suite("AppearanceProfile — legacy flag migration") {
        test("legacy showYear maps to dance + cortina year visibility") {
            let p = try decode(legacyFlagsJSON)
            try expect(p.showYearDance)
            try expect(p.showYearCortina)
        }
        test("legacy showSinger maps to showSingerDance") {
            let p = try decode(legacyFlagsJSON)
            try expect(p.showSingerDance)
        }
        test("legacy showAlbumArtwork maps to artwork dance + cortina") {
            let p = try decode(legacyFlagsJSON)
            try expect(p.showArtworkDance)
            try expect(p.showArtworkCortina)
        }
    }

    suite("AppearanceProfile — position offsets") {
        test("offsets default to 0 when absent in legacy JSON") {
            let p = try decode(minimalJSON)
            try expectEqual(p.titleOffsetX, 0)
            try expectEqual(p.titleOffsetY, 0)
            try expectEqual(p.artistOffsetX, 0)
            try expectEqual(p.singerOffsetY, 0)
            try expectEqual(p.trackCounterOffsetX, 0)
            try expectEqual(p.cortinaLabelOffsetX, 0)
            try expectEqual(p.nextUpLabelOffsetY, 0)
        }
        test("box widths default in legacy JSON") {
            let p = try decode(minimalJSON)
            try expectEqual(p.titleBoxWidth, 0)
            try expectEqual(p.singerBoxWidth, 0)
        }
        test("set offsets survive an encode/decode round-trip") {
            var p = AppearanceProfile(id: UUID(), name: "Offsets", isBuiltIn: false)
            p.titleOffsetX = 120;  p.titleOffsetY = -40
            p.artistOffsetX = -15; p.artistOffsetY = 8
            p.cortinaLabelOffsetX = 33
            p.nextUpLabelOffsetY = 77
            let data = try JSONEncoder().encode(p)
            let back = try JSONDecoder().decode(AppearanceProfile.self, from: data)
            try expectEqual(back.titleOffsetX, 120)
            try expectEqual(back.titleOffsetY, -40)
            try expectEqual(back.artistOffsetX, -15)
            try expectEqual(back.artistOffsetY, 8)
            try expectEqual(back.cortinaLabelOffsetX, 33)
            try expectEqual(back.nextUpLabelOffsetY, 77)
        }
    }

    suite("AppearanceProfile — decoder is idempotent") {
        test("re-encoding a decoded profile and decoding again is stable") {
            let once = try decode(minimalJSON)
            let reencoded = try JSONEncoder().encode(once)
            let twice = try JSONDecoder().decode(AppearanceProfile.self, from: reencoded)
            try expectEqual(twice, once)
        }
        test("built-in profile survives an encode/decode round-trip") {
            let data = try JSONEncoder().encode(AppearanceProfile.modern)
            let back = try JSONDecoder().decode(AppearanceProfile.self, from: data)
            try expectEqual(back.id, AppearanceProfile.modern.id)
            try expectEqual(back.backgroundColor, AppearanceProfile.modern.backgroundColor)
        }
    }
}

// MARK: - ProfileStore image-path & cleanup tests

func runProfileStoreImageTests() {
    func tmpProfilesDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TangoDisplayTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    suite("ProfileStore — image paths") {
        test("imagesDirectoryURL is a sibling of the profiles dir") {
            let profilesURL = tmpProfilesDir()
            defer { try? FileManager.default.removeItem(at: profilesURL.deletingLastPathComponent()) }
            let store = ProfileStore(storeURL: profilesURL)
            try expectEqual(store.imagesDirectoryURL.lastPathComponent, "images")
            try expectEqual(store.imagesDirectoryURL.deletingLastPathComponent().path,
                            profilesURL.deletingLastPathComponent().path)
        }
        test("imageURL appends the filename") {
            let store = ProfileStore(storeURL: tmpProfilesDir())
            try expectEqual(store.imageURL(for: "x.jpg").lastPathComponent, "x.jpg")
        }
        test("createImagesDirectoryIfNeeded creates the directory") {
            let profilesURL = tmpProfilesDir()
            defer { try? FileManager.default.removeItem(at: profilesURL.deletingLastPathComponent()) }
            let store = ProfileStore(storeURL: profilesURL)
            try expect(!FileManager.default.fileExists(atPath: store.imagesDirectoryURL.path))
            store.createImagesDirectoryIfNeeded()
            try expect(FileManager.default.fileExists(atPath: store.imagesDirectoryURL.path))
        }
    }

    suite("ProfileStore — delete removes associated images") {
        test("background image and artist images are removed on delete") {
            let profilesURL = tmpProfilesDir()
            defer { try? FileManager.default.removeItem(at: profilesURL.deletingLastPathComponent()) }
            let store = ProfileStore(storeURL: profilesURL)
            store.createImagesDirectoryIfNeeded()

            let bgURL = store.imageURL(for: "bg.jpg")
            let artURL = store.imageURL(for: "artist-1.jpg")
            try Data([0x1]).write(to: bgURL)
            try Data([0x2]).write(to: artURL)

            var profile = AppearanceProfile(id: UUID(), name: "WithImages", isBuiltIn: false)
            profile.backgroundImageFilename = "bg.jpg"
            profile.artistBackgrounds = [ArtistBackground(artistName: "X", imageFilename: "artist-1.jpg")]
            try store.save(profile)
            try store.delete(profile)

            try expect(!FileManager.default.fileExists(atPath: bgURL.path), "background image should be deleted")
            try expect(!FileManager.default.fileExists(atPath: artURL.path), "artist image should be deleted")
        }
    }

    suite("ProfileStore — load robustness") {
        test("skips invalid JSON and sorts user profiles by name") {
            let profilesURL = tmpProfilesDir()
            defer { try? FileManager.default.removeItem(at: profilesURL.deletingLastPathComponent()) }
            let store = ProfileStore(storeURL: profilesURL)
            try store.save(AppearanceProfile(id: UUID(), name: "Bravo", isBuiltIn: false))
            try store.save(AppearanceProfile(id: UUID(), name: "Alpha", isBuiltIn: false))
            try Data("not valid json".utf8).write(to: profilesURL.appendingPathComponent("junk.json"))

            let fresh = ProfileStore(storeURL: profilesURL)
            fresh.load()
            try expectEqual(fresh.userProfiles.count, 2)
            try expectEqual(fresh.userProfiles.map(\.name), ["Alpha", "Bravo"])
        }
    }
}

// MARK: - Regex transform tests

func runRegexTransformTests() {
    suite("applyRegexTransform") {
        test("extracts trailing capture group ('con …')") {
            try expectEqual(
                applyRegexTransform("Carlos di Sarli con Roberto Ruffino", pattern: "^.*(con .+)$", replacement: "$1"),
                "con Roberto Ruffino")
        }
        test("extracts the singer name only") {
            try expectEqual(
                applyRegexTransform("Carlos di Sarli con Roberto Ruffino", pattern: ".* con (.+)$", replacement: "$1"),
                "Roberto Ruffino")
        }
        test("no match keeps the original by default") {
            try expectEqual(applyRegexTransform("Osvaldo Pugliese", pattern: "(con .+)$", replacement: "$1"),
                            "Osvaldo Pugliese")
        }
        test("no match clears the field when clearWhenNoMatch is set") {
            try expectEqual(applyRegexTransform("Osvaldo Pugliese", pattern: "(con .+)$", replacement: "$1",
                                                clearWhenNoMatch: true), "")
        }
        test("match returns the extracted value regardless of the flag") {
            let input = "Carlos di Sarli con Roberto Ruffino"
            try expectEqual(applyRegexTransform(input, pattern: "^.*(con .+)$", replacement: "$1",
                                                clearWhenNoMatch: true), "con Roberto Ruffino")
        }
        test("empty pattern returns the original (no transform)") {
            try expectEqual(applyRegexTransform("X", pattern: "", replacement: "$1", clearWhenNoMatch: true), "X")
        }
        test("invalid pattern returns the original (no transform)") {
            try expectEqual(applyRegexTransform("X", pattern: "(", replacement: "$1", clearWhenNoMatch: true), "X")
        }
        test("whitespace-only result keeps original by default; empty when clearing") {
            try expectEqual(applyRegexTransform("Hello", pattern: ".*", replacement: "   "), "Hello")
            try expectEqual(applyRegexTransform("Hello", pattern: ".*", replacement: "   ", clearWhenNoMatch: true), "")
        }
        test("\\n escape produces a line break") {
            try expectEqual(applyRegexTransform("A B", pattern: " ", replacement: "\\n"), "A\nB")
        }
    }
}

// MARK: - Singer source / resolvedSinger tests

func runSingerTests() {
    func track(artist: String = "Carlos di Sarli con Roberto Ruffino",
               comment: String? = nil, albumArtist: String? = nil, grouping: String? = nil) -> Track {
        Track(title: "T", artist: artist, genre: "Tango", persistentID: "1",
              comment: comment, albumArtist: albumArtist, grouping: grouping)
    }
    func profile(_ mutate: (inout AppearanceProfile) -> Void) -> AppearanceProfile {
        var p = AppearanceProfile(id: UUID(), name: "P", isBuiltIn: false)
        mutate(&p); return p
    }

    suite("SingerSource — sources & migration") {
        test("exactly three sources, no Artist case") {
            try expectEqual(SingerSource.allCases.count, 3)
            try expect(!SingerSource.allCases.contains(where: { $0.rawValue == "artist" }))
        }
        test("trackInfoField maps each source to its field") {
            try expectEqual(SingerSource.comments.trackInfoField, .comments)
            try expectEqual(SingerSource.albumArtist.trackInfoField, .albumArtist)
            try expectEqual(SingerSource.grouping.trackInfoField, .grouping)
        }
        test("legacy singerSource 'artist' decodes to .comments without failing the profile") {
            let p = profile { $0.singerSource = .comments }
            var dict = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(p)) as! [String: Any]
            dict["singerSource"] = "artist"
            let data = try JSONSerialization.data(withJSONObject: dict)
            let back = try JSONDecoder().decode(AppearanceProfile.self, from: data)
            try expectEqual(back.singerSource, .comments)
        }
    }
}

// MARK: - Track-info field remap + transform resolver (Core)

func runTrackInfoTransformTests() {
    let full = Track(title: "Arrabalero", artist: "Carlos di Sarli con Roberto Ruffino",
                     genre: "Tango", persistentID: "1", year: 1939,
                     comment: "instrumental", albumArtist: "Di Sarli", grouping: "Vals")
    let sparse = Track(title: "T", artist: "A", genre: "G", persistentID: "2")

    suite("TrackInfoField — rawValue(from:)") {
        test("each field reads its track value") {
            try expectEqual(TrackInfoField.artist.rawValue(from: full), "Carlos di Sarli con Roberto Ruffino")
            try expectEqual(TrackInfoField.title.rawValue(from: full), "Arrabalero")
            try expectEqual(TrackInfoField.year.rawValue(from: full), "1939")
            try expectEqual(TrackInfoField.albumArtist.rawValue(from: full), "Di Sarli")
            try expectEqual(TrackInfoField.comments.rawValue(from: full), "instrumental")
            try expectEqual(TrackInfoField.grouping.rawValue(from: full), "Vals")
        }
        test("absent optionals and year yield empty string") {
            try expectEqual(TrackInfoField.year.rawValue(from: sparse), "")
            try expectEqual(TrackInfoField.albumArtist.rawValue(from: sparse), "")
            try expectEqual(TrackInfoField.comments.rawValue(from: sparse), "")
            try expectEqual(TrackInfoField.grouping.rawValue(from: sparse), "")
        }
    }

    suite("resolveTrackField") {
        test("no rule returns the field's own raw value") {
            try expectEqual(resolveTrackField(.artist, from: full, rules: [:]),
                            "Carlos di Sarli con Roberto Ruffino")
        }
        test("sourceField copies another field's value (Album Artist from Artist)") {
            let rules = ["albumArtist": TransformRule(sourceField: .artist)]
            try expectEqual(resolveTrackField(.albumArtist, from: full, rules: rules),
                            "Carlos di Sarli con Roberto Ruffino")
        }
        test("sourceField then regex (remap applied before transform)") {
            let rules = ["albumArtist": TransformRule(enabled: true, pattern: "^.*(con .+)$",
                                                      replacement: "$1", sourceField: .artist)]
            try expectEqual(resolveTrackField(.albumArtist, from: full, rules: rules),
                            "con Roberto Ruffino")
        }
        test("disabled rule returns raw value even with a pattern") {
            let rules = ["artist": TransformRule(enabled: false, pattern: "x", replacement: "y")]
            try expectEqual(resolveTrackField(.artist, from: full, rules: rules),
                            "Carlos di Sarli con Roberto Ruffino")
        }
        test("non-matching pattern: keeps source by default, clears when flag set") {
            let keep = ["albumArtist": TransformRule(enabled: true, pattern: "(con .+)$",
                                                     replacement: "$1", sourceField: .artist)]
            // sparse has artist "A" → no "con" match
            try expectEqual(resolveTrackField(.albumArtist, from: sparse, rules: keep), "A")
            let clear = ["albumArtist": TransformRule(enabled: true, pattern: "(con .+)$",
                                                      replacement: "$1", sourceField: .artist,
                                                      clearWhenNoMatch: true)]
            try expectEqual(resolveTrackField(.albumArtist, from: sparse, rules: clear), "")
        }
    }

    suite("TransformRule — backward-compatible decoding") {
        test("decodes older JSON without sourceField") {
            let json = "{\"enabled\":true,\"pattern\":\"a\",\"replacement\":\"b\",\"testInput\":\"\"}"
            let r = try JSONDecoder().decode(TransformRule.self, from: json.data(using: .utf8)!)
            try expectNil(r.sourceField)
            try expectEqual(r.enabled, true)
            try expectEqual(r.pattern, "a")
            try expect(!r.clearWhenNoMatch)   // absent → legacy default
        }
        test("round-trips with sourceField + clearWhenNoMatch set") {
            let r = TransformRule(enabled: true, pattern: "p", replacement: "r",
                                  sourceField: .artist, clearWhenNoMatch: true)
            let back = try JSONDecoder().decode(TransformRule.self, from: JSONEncoder().encode(r))
            try expectEqual(back.sourceField, .artist)
            try expect(back.clearWhenNoMatch)
        }
    }
}

// MARK: - Auto-bypass rule (genre/year → plugin active/bypass)

func runAutoBypassRuleTests() {
    suite("AutoBypassRule — genreMatches") {
        test("empty genre list matches any genre") {
            let r = AutoBypassRule(matchGenres: [])
            try expect(r.genreMatches("Tango"))
            try expect(r.genreMatches(""))
        }
        test("exact case-insensitive match") {
            let r = AutoBypassRule(matchGenres: ["Vals", "Milonga"])
            try expect(r.genreMatches("vals"))
            try expect(r.genreMatches("  MILONGA "))
            try expect(!r.genreMatches("Tango"))
        }
        test("word-boundary partial match") {
            let r = AutoBypassRule(matchGenres: ["Tango"])
            try expect(r.genreMatches("Tango Vals"))
            try expect(r.genreMatches("Argentine Tango"))
            try expect(!r.genreMatches("Tangoland"))
        }
    }

    suite("AutoBypassRule — yearMatches") {
        test("no threshold matches any year") {
            let r = AutoBypassRule()
            try expect(r.yearMatches(1935))
            try expect(r.yearMatches(nil))
        }
        test("olderThan: strictly before threshold; missing year is younger → no match") {
            let r = AutoBypassRule(yearThreshold: 1950, yearMode: .olderThan)
            try expect(r.yearMatches(1949))
            try expect(!r.yearMatches(1950))
            try expect(!r.yearMatches(1980))
            try expect(!r.yearMatches(nil))
        }
        test("fromYearOnwards: at/after threshold; missing year is younger → match") {
            let r = AutoBypassRule(yearThreshold: 1950, yearMode: .fromYearOnwards)
            try expect(r.yearMatches(1950))
            try expect(r.yearMatches(1980))
            try expect(!r.yearMatches(1949))
            try expect(r.yearMatches(nil))
        }
    }

    suite("AutoBypassRule — shouldBeActive") {
        test("activate: active only when matched") {
            let r = AutoBypassRule(matchGenres: ["Tango"], yearThreshold: 1950,
                                   yearMode: .olderThan, action: .activate)
            try expect(r.shouldBeActive(genre: "Tango", year: 1945))    // genre+year match → active
            try expect(!r.shouldBeActive(genre: "Tango", year: 1960))   // year fails → bypass
            try expect(!r.shouldBeActive(genre: "Vals", year: 1945))    // genre fails → bypass
        }
        test("bypass: bypassed only when matched") {
            let r = AutoBypassRule(matchGenres: ["Vals", "Milonga"], action: .bypass)
            try expect(!r.shouldBeActive(genre: "Vals", year: nil))     // match → bypass (not active)
            try expect(r.shouldBeActive(genre: "Tango", year: nil))     // no match → active
        }
        test("genre-only and year-only rules") {
            let genreOnly = AutoBypassRule(matchGenres: ["Tango"], action: .activate)
            try expect(genreOnly.shouldBeActive(genre: "Tango", year: 2000))
            let yearOnly = AutoBypassRule(yearThreshold: 1950, yearMode: .olderThan, action: .activate)
            try expect(yearOnly.shouldBeActive(genre: "anything", year: 1940))
            try expect(!yearOnly.shouldBeActive(genre: "anything", year: nil))
        }
        test("matchMode .any (OR): bypass when genre OR year matches") {
            // bypass when (genre = Cortina) OR (older than 1950)
            let r = AutoBypassRule(matchGenres: ["Cortina"], yearThreshold: 1950,
                                   yearMode: .olderThan, action: .bypass, matchMode: .any)
            try expect(!r.shouldBeActive(genre: "Cortina", year: 2020))  // genre hit → bypass
            try expect(!r.shouldBeActive(genre: "Pop", year: 1940))      // year hit → bypass
            try expect(!r.shouldBeActive(genre: "Cortina", year: 1940))  // both → bypass
            try expect(r.shouldBeActive(genre: "Pop", year: 2020))       // neither → active
        }
        test("matchMode .all (AND) default still requires both") {
            let r = AutoBypassRule(matchGenres: ["Cortina"], yearThreshold: 1950,
                                   yearMode: .olderThan, action: .bypass)  // default .all
            try expect(!r.shouldBeActive(genre: "Cortina", year: 1940))  // both → bypass
            try expect(r.shouldBeActive(genre: "Cortina", year: 2020))   // only genre → active (not bypassed)
        }
        test(".any ignores unset conditions") {
            let genreOnlyAny = AutoBypassRule(matchGenres: ["Cortina"], action: .bypass, matchMode: .any)
            try expect(!genreOnlyAny.shouldBeActive(genre: "Cortina", year: 2020))  // genre hit → bypass
            try expect(genreOnlyAny.shouldBeActive(genre: "Pop", year: 1900))       // no genre, year unset → active
        }
    }

    suite("AudioUnitChainSlot — autoBypassRule coding") {
        let selection = AudioUnitPluginSelection(name: "EQ", manufacturerName: "X",
                                                 componentType: 1, componentSubType: 2, componentManufacturer: 3)
        test("legacy slot without the key decodes to nil rule") {
            let slot = AudioUnitChainSlot(selection: selection)
            let data = try JSONEncoder().encode(slot)
            // encodeIfPresent omits the key for a nil optional → mimics older persisted data
            let json = String(data: data, encoding: .utf8) ?? ""
            try expect(!json.contains("autoBypassRule"))
            let back = try JSONDecoder().decode(AudioUnitChainSlot.self, from: data)
            try expectNil(back.autoBypassRule)
        }
        test("round-trips with a rule set") {
            let rule = AutoBypassRule(matchGenres: ["Tango"], yearThreshold: 1950,
                                      yearMode: .fromYearOnwards, action: .bypass)
            let slot = AudioUnitChainSlot(selection: selection, autoBypassRule: rule)
            let back = try JSONDecoder().decode(AudioUnitChainSlot.self,
                                                from: JSONEncoder().encode(slot))
            try expectEqual(back.autoBypassRule, rule)
        }
    }
}

// MARK: - Relative text positioning + alignment

func runRelativePositionTests() {
    func baseProfile() -> AppearanceProfile { AppearanceProfile(id: UUID(), name: "P", isBuiltIn: false) }
    func legacyDict(_ mutate: (inout [String: Any]) -> Void) throws -> Data {
        var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(baseProfile())) as! [String: Any]
        dict.removeValue(forKey: "relativePositions")  // simulate older profile
        mutate(&dict)
        return try JSONSerialization.data(withJSONObject: dict)
    }

    suite("AppearanceProfile — relative-position migration") {
        test("absolute px offsets/box migrate to percent of 1920×1080") {
            let data = try legacyDict {
                $0["titleOffsetX"] = 192.0    // 10% of 1920
                $0["titleOffsetY"] = 108.0    // 10% of 1080
                $0["artistBoxWidth"] = 384.0  // 20% of 1920
            }
            let p = try JSONDecoder().decode(AppearanceProfile.self, from: data)
            try expect(p.relativePositions)
            try expect(abs(p.titleOffsetX - 10.0) < 0.001)
            try expect(abs(p.titleOffsetY - 10.0) < 0.001)
            try expect(abs(p.artistBoxWidth - 20.0) < 0.001)
        }
        test("non-zero legacy X offset becomes left-aligned; others stay centred") {
            let data = try legacyDict { $0["genreOffsetX"] = 300.0 }
            let p = try JSONDecoder().decode(AppearanceProfile.self, from: data)
            try expectEqual(p.genreHAlign, .leading)
            try expectEqual(p.titleHAlign, .center)
        }
        test("absolute artwork offset migrates to percent of 1920×1080") {
            let data = try legacyDict {
                $0.removeValue(forKey: "relativeArtworkPosition")
                $0["albumArtworkOffsetX"] = 192.0   // 10% of 1920
                $0["albumArtworkOffsetY"] = 540.0   // 50% of 1080
            }
            let p = try JSONDecoder().decode(AppearanceProfile.self, from: data)
            try expect(p.relativeArtworkPosition)
            try expect(abs(p.albumArtworkOffsetX - 10.0) < 0.001)
            try expect(abs(p.albumArtworkOffsetY - 50.0) < 0.001)
        }
        test("already-relative profile is not re-converted (idempotent)") {
            var p = baseProfile()
            p.titleOffsetX = 10.0
            let back = try JSONDecoder().decode(AppearanceProfile.self, from: JSONEncoder().encode(p))
            try expect(back.relativePositions)
            try expect(abs(back.titleOffsetX - 10.0) < 0.001)  // unchanged, not divided by 1920
        }
    }

    suite("TextHAlignment") {
        test("default alignment is centre") {
            try expectEqual(baseProfile().titleHAlign, .center)
        }
        test("codable round-trip for all cases") {
            for a in TextHAlignment.allCases {
                let back = try JSONDecoder().decode([TextHAlignment].self, from: JSONEncoder().encode([a]))
                try expectEqual(back, [a])
            }
        }
        test("profile round-trips percent offsets + alignment") {
            var p = baseProfile()
            p.titleOffsetX = -25.5; p.titleHAlign = .trailing; p.artistBoxWidth = 33.0
            let back = try JSONDecoder().decode(AppearanceProfile.self, from: JSONEncoder().encode(p))
            try expect(abs(back.titleOffsetX - (-25.5)) < 0.001)
            try expectEqual(back.titleHAlign, .trailing)
            try expect(abs(back.artistBoxWidth - 33.0) < 0.001)
        }
    }

    suite("AppearanceProfile — relative font-size migration") {
        test("absolute point sizes migrate to levels (percent of 1080)") {
            let data = try legacyDict {
                $0.removeValue(forKey: "relativeFontSizes")
                $0["titleFontSize"] = 72.0    // → 7
                $0["artistFontSize"] = 96.0   // → 9
                $0["genreFontSize"] = 36.0    // → 3
            }
            let p = try JSONDecoder().decode(AppearanceProfile.self, from: data)
            try expect(p.relativeFontSizes)
            try expect(abs(p.titleFontSize - 7) < 0.001)
            try expect(abs(p.artistFontSize - 9) < 0.001)
            try expect(abs(p.genreFontSize - 3) < 0.001)
        }
        test("already-relative font sizes are not re-converted") {
            var p = baseProfile()
            p.titleFontSize = 8
            let back = try JSONDecoder().decode(AppearanceProfile.self, from: JSONEncoder().encode(p))
            try expect(back.relativeFontSizes)
            try expect(abs(back.titleFontSize - 8) < 0.001)
        }
        test("built-in defaults are levels in 1...15") {
            let p = baseProfile()
            for size in [p.titleFontSize, p.artistFontSize, p.genreFontSize, p.lastPlayedFontSize] {
                try expect(size >= 1 && size <= 15)
            }
        }
    }
}

// MARK: - Presentation options (genre case, fade style, last played)

func runPresentationOptionTests() {
    func base() -> AppearanceProfile { AppearanceProfile(id: UUID(), name: "P", isBuiltIn: false) }

    suite("GenreTextCase") {
        test("apply transforms text per case") {
            try expectEqual(GenreTextCase.uppercase.apply("Tango Vals"), "TANGO VALS")
            try expectEqual(GenreTextCase.original.apply("Tango Vals"), "Tango Vals")
            try expectEqual(GenreTextCase.titleCase.apply("tango vals"), "Tango Vals")
        }
        test("codable round-trip") {
            for c in GenreTextCase.allCases {
                let back = try JSONDecoder().decode([GenreTextCase].self, from: JSONEncoder().encode([c]))
                try expectEqual(back, [c])
            }
        }
    }

    suite("AppearanceProfile — new option defaults") {
        test("defaults: uppercase genre, radial fade, last-played off") {
            let p = base()
            try expectEqual(p.genreTextCase, .uppercase)
            try expectEqual(p.albumArtworkFadeStyle, .radial)
            try expect(!p.showLastPlayedDance)
            try expect(!p.showLastPlayedCortina)
        }
        test("DisplayTextItem includes lastPlayed; order lists contain it") {
            try expect(DisplayTextItem.allCases.contains(.lastPlayed))
            try expect(base().danceItemOrder.contains(.lastPlayed))
            try expect(base().cortinaItemOrder.contains(.lastPlayed))
        }
        test("legacy profile without new keys decodes to defaults + appends lastPlayed to orders") {
            var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(base())) as! [String: Any]
            for k in ["genreTextCase", "albumArtworkFadeStyle", "showLastPlayedDance",
                      "showLastPlayedCortina", "danceItemOrder", "cortinaItemOrder"] {
                dict.removeValue(forKey: k)
            }
            let p = try JSONDecoder().decode(AppearanceProfile.self,
                                             from: try JSONSerialization.data(withJSONObject: dict))
            try expectEqual(p.genreTextCase, .uppercase)
            try expectEqual(p.albumArtworkFadeStyle, .radial)
            try expect(p.danceItemOrder.contains(.lastPlayed))
            try expect(p.cortinaItemOrder.contains(.lastPlayed))
        }
    }
}

// MARK: - Per-genre position overrides

func runGenrePositionOverrideTests() {
    func base() -> AppearanceProfile { AppearanceProfile(id: UUID(), name: "P", isBuiltIn: false) }
    // No allow/deny → nothing classified as cortina.
    let detector = CortinaDetector(useAllowlist: false, allowlistGenres: [],
                                   useDenylist: false, denylistGenres: [])

    suite("GenreBackground.positions coding") {
        test("legacy entry without positions decodes to nil") {
            let g = GenreBackground(genreKey: "Tango", imageFilename: "g.jpg")
            let data = try JSONEncoder().encode(g)
            try expect(!(String(data: data, encoding: .utf8) ?? "").contains("positions"))
            try expectNil(try JSONDecoder().decode(GenreBackground.self, from: data).positions)
        }
        test("round-trips with a position set") {
            let set = PositionSet(placements: ["title": ElementPlacement(offsetX: 12, hAlign: .trailing)])
            let g = GenreBackground(genreKey: "Tango", positions: set)
            let back = try JSONDecoder().decode(GenreBackground.self, from: JSONEncoder().encode(g))
            try expectEqual(back.positions, set)
        }
    }

    suite("AppearanceProfile — applyingPositionOverride") {
        test("nil override returns the profile unchanged") {
            let p = base()
            try expectEqual(p.applyingPositionOverride(nil), p)
        }
        test("override replaces only the listed element's flat fields") {
            var p = base()
            p.artistOffsetX = 5
            let set = PositionSet(placements: ["title": ElementPlacement(offsetX: 30, offsetY: 40,
                                                                         boxWidth: 50, hAlign: .leading)])
            let out = p.applyingPositionOverride(set)
            try expect(abs(out.titleOffsetX - 30) < 0.001)
            try expect(abs(out.titleOffsetY - 40) < 0.001)
            try expect(abs(out.titleBoxWidth - 50) < 0.001)
            try expectEqual(out.titleHAlign, .leading)
            try expect(abs(out.artistOffsetX - 5) < 0.001)   // untouched
        }
        test("currentPlacements reflects flat fields and round-trips through override") {
            var p = base()
            p.genreOffsetX = -20; p.genreHAlign = .trailing
            let placements = p.currentPlacements()
            try expect(abs((placements.placements["genre"]?.offsetX ?? 0) - (-20)) < 0.001)
            try expectEqual(placements.placements["genre"]?.hAlign, .trailing)
        }
        test("artwork override replaces album-artwork placement") {
            var p = base()
            p.albumArtworkOffsetX = 0; p.albumArtworkScale = 1
            let set = PositionSet(artwork: ArtworkPlacement(offsetX: 120, offsetY: -60, scale: 2.5, opacity: 0.8))
            let out = p.applyingPositionOverride(set)
            try expect(abs(out.albumArtworkOffsetX - 120) < 0.001)
            try expect(abs(out.albumArtworkOffsetY - (-60)) < 0.001)
            try expect(abs(out.albumArtworkScale - 2.5) < 0.001)
            try expect(abs(out.albumArtworkOpacity - 0.8) < 0.001)
        }
        test("currentPlacements seeds artwork from the profile") {
            var p = base()
            p.albumArtworkScale = 1.7
            try expect(abs((p.currentPlacements().artwork?.scale ?? 0) - 1.7) < 0.001)
        }
        test("save→load round-trips text + artwork placements losslessly") {
            var src = base()
            src.titleOffsetX = 12.5; src.titleHAlign = .trailing; src.artistBoxWidth = 40
            src.singerOffsetY = -7
            src.albumArtworkOffsetX = 25; src.albumArtworkOffsetY = -15; src.albumArtworkScale = 1.4
            let set = src.currentPlacements()                  // "Save to genre"
            let loaded = base().applyingPositionOverride(set)  // "Load from genre" onto defaults
            try expect(abs(loaded.titleOffsetX - 12.5) < 0.001)
            try expectEqual(loaded.titleHAlign, .trailing)
            try expect(abs(loaded.artistBoxWidth - 40) < 0.001)
            try expect(abs(loaded.singerOffsetY - (-7)) < 0.001)
            try expect(abs(loaded.albumArtworkOffsetX - 25) < 0.001)
            try expect(abs(loaded.albumArtworkOffsetY - (-15)) < 0.001)
            try expect(abs(loaded.albumArtworkScale - 1.4) < 0.001)
        }
        test("save to a genre then read back via positionOverride") {
            var p = base()
            p.genreBackgroundsEnabled = true
            p.titleOffsetX = 9; p.albumArtworkScale = 2.0
            var g = GenreBackground(genreKey: "Tango")
            g.positions = p.currentPlacements()
            p.genreBackgrounds = [g]
            let set = p.positionOverride(forGenre: "Tango", using: detector)
            try expect(abs((set?.placements["title"]?.offsetX ?? 0) - 9) < 0.001)
            try expect(abs((set?.artwork?.scale ?? 0) - 2.0) < 0.001)
        }
    }

    suite("AppearanceProfile — positionOverride(forGenre:)") {
        test("returns the matching genre entry's override") {
            var p = base()
            p.genreBackgroundsEnabled = true
            let set = PositionSet(placements: ["title": ElementPlacement(offsetX: 9)])
            p.genreBackgrounds = [GenreBackground(genreKey: "Tango", positions: set)]
            try expectEqual(p.positionOverride(forGenre: "Tango", using: detector), set)
            try expectNil(p.positionOverride(forGenre: "Milonga", using: detector))
        }
        test("nil when genre backgrounds disabled") {
            var p = base()
            p.genreBackgroundsEnabled = false
            p.genreBackgrounds = [GenreBackground(genreKey: "Tango",
                                                  positions: PositionSet(placements: ["title": ElementPlacement()]))]
            try expectNil(p.positionOverride(forGenre: "Tango", using: detector))
        }
    }
}

// MARK: - Main entry point

runCortinaDetectorTests()
runTandaTrackerTests()
runProfileStoreTests()
runDisplayStateTests()
runReplayGainTests()
runAutoReplayGainTests()
runAudioUnitPluginTests()
runTandaPositionTests()
runAudioUnitPresetTests()
runAudioUnitPluginStatusShortTextTests()
runReplayGainModeTests()
runLoudnessAnalysisResultTests()
runCodableModelTests()
runEnumDisplayTests()
runAppearanceProfileMatchingTests()
runAppearanceProfileMigrationTests()
runProfileStoreImageTests()
runRegexTransformTests()
runSingerTests()
runTrackInfoTransformTests()
runAutoBypassRuleTests()
runRelativePositionTests()
runPresentationOptionTests()
runGenrePositionOverrideTests()

print("\n════════════════════════════════")
let icon = totalFailed == 0 ? "✓" : "✗"
print("\(icon) \(totalPassed) passed, \(totalFailed) failed")
print("════════════════════════════════")

if totalFailed > 0 {
    exit(1)
}
