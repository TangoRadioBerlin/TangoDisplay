import Foundation
import Combine
import TangoDisplayCore
import UniformTypeIdentifiers

/// Mediates between the TangoDisplay app state and a `RemoteTransport`.
///
/// Once a transport is attached, the underlying listener stays bound for the lifetime
/// of the app process. The user-facing on/off toggle calls `resume()` / `pause()`,
/// which only gates acceptance — it does NOT re-bind the port. This avoids the
/// EADDRINUSE / NWError 48 race that occurs when a TCP listener is cancelled and
/// rebound on the same port in quick succession on macOS. A full teardown only
/// happens via `teardown(completion:)`, called from `applicationWillTerminate`.
@MainActor
final class RemoteControlBridge: NSObject, ObservableObject {

    private let appState: AppState
    private let settings: AppSettings
    private var transport: RemoteTransport?

    private var stateCancellables = Set<AnyCancellable>()
    private var transportCancellables = Set<AnyCancellable>()
    private var authenticatedClients = Set<UUID>()
    private var pinLimiter = PinRateLimiter()

    private let stateChangeSubject = PassthroughSubject<Void, Never>()

    @Published private(set) var connectionCount: Int = 0
    /// True while a transport is attached and its listener is bound.
    @Published private(set) var isRunning: Bool = false
    /// True while inbound auth + commands are honoured. When false, new connections
    /// are dropped immediately and existing clients are disconnected.
    @Published private(set) var isAcceptingClients: Bool = false
    @Published private(set) var lastError: String? = nil

    init(appState: AppState, settings: AppSettings) {
        self.appState = appState
        self.settings = settings
    }

    // MARK: - Attach / resume / pause / teardown

    /// One-time attach: creates the listener and starts accepting clients. Called from
    /// `AppState` the first time the user enables Setlist Remote in a session.
    func attach(transport: RemoteTransport) throws {
        if let old = self.transport {
            // Previous attach failed (e.g. port really was in use). Drop the old
            // instance — if it had bound the port we wouldn't be retrying.
            old.stop(completion: {})
            transportCancellables.removeAll()
        }
        self.transport = transport
        transport.delegate = self
        if let http = transport as? HTTPServerTransport {
            http.onListenerFailure = { [weak self] message in
                Task { @MainActor in self?.reportStartError(message) }
            }
        }
        try transport.start()
        transport.connectionCountPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in self?.connectionCount = count }
            .store(in: &transportCancellables)
        subscribeToState()
        isRunning = true
        isAcceptingClients = true
        lastError = nil
    }

    /// Re-enable acceptance after a `pause()`. Cheap and safe to call repeatedly.
    func resume() {
        guard isRunning else { return }
        isAcceptingClients = true
        lastError = nil
    }

    /// Disable acceptance: kicks every connected client and refuses new auth attempts.
    /// The listener stays bound — see the type doc-comment for why.
    func pause() {
        guard isRunning else { return }
        isAcceptingClients = false
        guard let transport else { return }
        for clientID in authenticatedClients {
            transport.disconnect(clientID)
        }
        authenticatedClients.removeAll()
    }

    /// Full shutdown — cancels the listener and tears down all subscriptions.
    /// Intended for `applicationWillTerminate`; not used by the on/off toggle.
    func teardown(completion: (@Sendable () -> Void)? = nil) {
        stateCancellables.removeAll()
        transportCancellables.removeAll()
        authenticatedClients.removeAll()
        connectionCount = 0
        isRunning = false
        isAcceptingClients = false
        let t = transport
        transport = nil
        if let t {
            t.stop(completion: completion ?? {})
        } else {
            completion?()
        }
    }

    func reportStartError(_ message: String) {
        lastError = message
        isRunning = false
        isAcceptingClients = false
    }

    // MARK: - State subscription

    private func subscribeToState() {
        // Any change to a subscribed publisher emits on stateChangeSubject;
        // throttling coalesces rapid slider drags into one snapshot per 100 ms.
        let settings = self.settings
        let appState = self.appState

        settings.$builtInVolume.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)
        settings.$cortinaVolumeReductionDb.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)
        settings.$replayGainMode.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)
        settings.$replayGainPreampDb.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)
        settings.$replayGainPreventClipping.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)
        settings.$replayGainTargetLufs.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)

        appState.$displayState.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)
        appState.$currentPlayerState.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)

        // v2: re-broadcast when the setlist changes or the controller scope is toggled.
        settings.$remoteControlAllowSetlistControl.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)
        appState.setlist.$entries.dropFirst().sink { [weak self] _ in self?.stateChangeSubject.send() }.store(in: &stateCancellables)

        stateChangeSubject
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.broadcastSnapshot() }
            .store(in: &stateCancellables)
    }

    private func broadcastSnapshot() {
        guard let transport, !authenticatedClients.isEmpty else { return }
        guard let json = snapshotJSON() else { return }
        for clientID in authenticatedClients {
            transport.send(json, to: clientID)
        }
    }

    // MARK: - Handshake

    /// v2 `hello`: advertises the protocol version and capabilities. Controller capabilities are
    /// only offered when the DJ has enabled remote setlist control. v1 clients ignore the extra
    /// fields. Falls back to the v1 shape if serialization ever fails.
    private func helloJSON() -> String {
        var caps: [String] = []
        if settings.remoteControlAllowSetlistControl {
            caps = [RemoteCapability.transport.rawValue, RemoteCapability.setlistRead.rawValue]
            if settings.remoteControlAllowSetlistLoad {
                caps.append(RemoteCapability.setlistWrite.rawValue)
            }
        }
        let dict: [String: Any] = [
            "type": "hello",
            "needsAuth": true,
            "protocolVersion": RemoteProtocol.version,
            "capabilities": caps
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return #"{"type":"hello","needsAuth":true}"#
    }

    // MARK: - JSON snapshot

    private func snapshotJSON() -> String? {
        let s = settings
        let display = appState.displayState
        let playerState = appState.currentPlayerState
        let local = appState.localPlayer

        var nowPlaying: [String: Any] = [
            "playerState": playerState.rawValue,
            "displayMode": displayModeString(display.mode),
            "snapshotAt": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let track = display.currentTrack {
            nowPlaying["title"] = track.title
            nowPlaying["artist"] = track.artist
            nowPlaying["genre"] = track.genre
        }
        if let tanda = display.tandaPosition {
            var t: [String: Any] = ["current": tanda.current]
            if let total = tanda.total { t["total"] = total }
            nowPlaying["tanda"] = t
        }
        if let local {
            nowPlaying["elapsedSec"] = local.elapsed
            nowPlaying["durationSec"] = local.duration
        }
        if let override = display.overrideText {
            nowPlaying["overrideText"] = override
        }

        var payload: [String: Any] = [
            "type": "state",
            "mainVolume": s.builtInVolume,
            "cortinaVolumeDb": s.cortinaVolumeReductionDb,
            "replayGain": [
                "mode": s.replayGainMode.rawValue,
                "preampDb": s.replayGainPreampDb,
                "preventClipping": s.replayGainPreventClipping,
                "targetLufs": s.replayGainTargetLufs
            ],
            "nowPlaying": nowPlaying
        ]

        // v2 additive: broadcast the full setlist only under the opt-in controller scope.
        // Carries no file paths; entryId is the stable SetlistEntry UUID.
        if s.remoteControlAllowSetlistControl, let setlist = setlistArrayJSON() {
            payload["setlist"] = setlist
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Builds `state.setlist[]` from the shared SetlistManager as JSON-object array (for splicing
    /// into the JSONSerialization payload). The wire shape is defined by the Core DTO.
    private func setlistArrayJSON() -> [[String: Any]]? {
        let detector = settings.makeDetector()
        let dtos = appState.setlist.entries.map { e in
            RemoteSetlistEntryDTO(
                entryId: e.id.uuidString,
                clientRef: e.clientRef,
                tandaRef: e.tandaRef,
                title: e.track.title,
                artist: e.track.artist,
                genre: e.track.genre,
                isCortina: detector.isCortina(genre: e.track.genre),
                state: e.state.rawValue,
                durationSec: e.duration,
                isPerformance: e.isPerformance)
        }
        guard let data = try? JSONEncoder().encode(dtos),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return arr
    }

    private func displayModeString(_ mode: DisplayMode) -> String {
        switch mode {
        case .playing:  return "playing"
        case .cortina:  return "cortina"
        case .idle:     return "idle"
        case .paused:   return "paused"
        case .override: return "override"
        case .performance: return "performance"
        }
    }

    // MARK: - Inbound command handling

    private func handle(message: String, from clientID: UUID) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        switch type {
        case "auth":
            handleAuth(pin: json["pin"] as? String, from: clientID)
        case "set":
            guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
            handleSet(field: json["field"] as? String, value: json["value"], from: clientID)
        case "transport":
            handleTransport(data: data, from: clientID)
        case "playEntry":
            handlePlayEntry(data: data, from: clientID)
        case "loadSetlist":
            handleLoadSetlist(data: data, from: clientID)
        case "setlist.insert":
            handleSetlistInsert(data: data, from: clientID)
        case "setlist.remove":
            handleSetlistRemove(data: data, from: clientID)
        case "setlist.move":
            handleSetlistMove(data: data, from: clientID)
        case "setlist.replaceFuture":
            handleSetlistReplaceFuture(data: data, from: clientID)
        default:
            break
        }
    }

    // MARK: - Controller commands (v2, gated by remoteControlAllowSetlistControl)

    /// Runs a controller command on the built-in player, auto-switching to it if another source is
    /// active (the switch is synchronous, so `apply` lands on the new source).
    private func applyOnBuiltIn(_ apply: () -> Void) {
        appState.ensureBuiltInPlayerActive()
        apply()
    }

    private func handleTransport(data: Data, from clientID: UUID) {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
        guard let cmd = RemoteCommandDecoder.transport(from: data) else {
            sendAck(id: nil, ok: false, reason: RemoteRejectReason.malformed, to: clientID)
            return
        }
        guard settings.remoteControlAllowSetlistControl else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.controllerDisabled, to: clientID)
            return
        }
        applyOnBuiltIn {
            switch cmd.action {
            case .play, .resume:   appState.transportPlay()
            case .pause:           appState.transportPause()
            case .next:            appState.transportSkipNext()
            case .previous:        appState.transportSkipPrevious()
            case .stop:            appState.transportStop()
            case .fadeAndStop:     appState.transportFadeAndStop()
            case .fadeAndContinue: appState.transportFadeAndContinue()
            }
        }
        sendAck(id: cmd.id, ok: true, to: clientID)
    }

    private func handlePlayEntry(data: Data, from clientID: UUID) {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
        guard let cmd = RemoteCommandDecoder.playEntry(from: data) else {
            sendAck(id: nil, ok: false, reason: RemoteRejectReason.malformed, to: clientID)
            return
        }
        guard settings.remoteControlAllowSetlistControl else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.controllerDisabled, to: clientID)
            return
        }
        guard let uuid = UUID(uuidString: cmd.entryId),
              let entry = appState.setlist.entries.first(where: { $0.id == uuid }) else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.unknownEntry, to: clientID)
            return
        }
        applyOnBuiltIn { appState.localPlayer?.jumpTo(entry) }
        sendAck(id: cmd.id, ok: true, to: clientID)
    }

    private func sendAck(id: String?, ok: Bool, reason: String? = nil,
                         resolved: [RemoteAck.Resolved]? = nil, failed: [RemoteAck.Failed]? = nil,
                         to clientID: UUID) {
        guard let transport else { return }
        let ack = RemoteAck(id: id, ok: ok, rejectedReason: reason, resolved: resolved, failed: failed)
        if let s = RemoteJSON.encodeToString(ack) {
            transport.send(s, to: clientID)
        }
    }

    // MARK: - Controller setlist write (v2 Slice 2, gated by remoteControlAllowSetlistLoad)

    /// Validates a controller-supplied path: absolute, existing, readable regular file, audio type.
    /// Returns a rejection reason, or nil when the path is acceptable.
    private func validateLoadPath(_ path: String) -> String? {
        guard path.hasPrefix("/") else { return RemoteRejectReason.pathNotAllowed }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return RemoteRejectReason.fileNotFound
        }
        if isDir.boolValue { return RemoteRejectReason.unsupportedType }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return RemoteRejectReason.unreadable
        }
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .audio) else {
            return RemoteRejectReason.unsupportedType
        }
        return nil
    }

    /// Builds a SetlistEntry from a validated load entry (path already checked). Reads file tags,
    /// applying the controller's optional title/artist overrides, and stamps the client refs.
    private func buildEntry(from le: RemoteLoadEntry) async -> SetlistEntry {
        let url = URL(fileURLWithPath: le.path)
        let base = await SetlistManager.readMetadata(from: url)
        let title = (le.title?.isEmpty == false) ? le.title! : base.title
        let artist = (le.artist?.isEmpty == false) ? le.artist! : base.artist
        let track = Track(title: title, artist: artist, genre: base.genre,
                          persistentID: base.persistentID, year: base.year, comment: base.comment,
                          albumArtist: base.albumArtist, grouping: base.grouping,
                          replayGainInfo: base.replayGainInfo, bpm: base.bpm)
        var entry = SetlistEntry(fileURL: url, track: track)
        entry.clientRef = le.clientRef
        entry.tandaRef = le.tandaRef
        return entry
    }

    /// Common gate for write commands: accepting, authenticated, and the load scope is enabled.
    /// Returns true when the command may proceed; otherwise sends the appropriate ack/skip.
    private func authorizeWrite(id: String?, from clientID: UUID) -> Bool {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return false }
        guard settings.remoteControlAllowSetlistLoad else {
            sendAck(id: id, ok: false, reason: RemoteRejectReason.controllerDisabled, to: clientID)
            return false
        }
        return true
    }

    private func handleLoadSetlist(data: Data, from clientID: UUID) {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
        guard let cmd = RemoteCommandDecoder.loadSetlist(from: data) else {
            sendAck(id: nil, ok: false, reason: RemoteRejectReason.malformed, to: clientID); return
        }
        guard authorizeWrite(id: cmd.id, from: clientID) else { return }
        // A2: cap entry count before any async work (each entry costs a MainActor metadata read).
        guard RemoteLoadLimits.isWithinLimit(cmd.entries.count) else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.tooManyEntries, to: clientID); return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Build entries first; no side-effects yet (metadata read, no setlist/player mutation).
            let (built, resolved, failed) = await self.buildEntries(cmd.entries)
            // A1: re-assert auth/accept after the await — the DJ may have toggled Remote off while
            // entries were being loaded. authorizeWrite sends controllerDisabled on scope-off.
            guard self.authorizeWrite(id: cmd.id, from: clientID) else { return }
            self.appState.ensureBuiltInPlayerActive()
            switch cmd.mode {
            case .append:  self.appState.setlist.insert(built, before: nil)
            case .replace: self.appState.setlist.replaceQueuedRegion(with: built)
            }
            self.sendAck(id: cmd.id, ok: true, resolved: resolved, failed: failed, to: clientID)
        }
    }

    private func handleSetlistReplaceFuture(data: Data, from clientID: UUID) {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
        guard let cmd = RemoteCommandDecoder.replaceFuture(from: data) else {
            sendAck(id: nil, ok: false, reason: RemoteRejectReason.malformed, to: clientID); return
        }
        guard authorizeWrite(id: cmd.id, from: clientID) else { return }
        // A2: cap entry count before any async work.
        guard RemoteLoadLimits.isWithinLimit(cmd.entries.count) else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.tooManyEntries, to: clientID); return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Build entries first; no side-effects yet.
            let (built, resolved, failed) = await self.buildEntries(cmd.entries)
            // A1: re-assert auth/accept after the await.
            guard self.authorizeWrite(id: cmd.id, from: clientID) else { return }
            self.appState.ensureBuiltInPlayerActive()
            self.appState.setlist.replaceQueuedRegion(with: built)
            self.sendAck(id: cmd.id, ok: true, resolved: resolved, failed: failed, to: clientID)
        }
    }

    private func handleSetlistInsert(data: Data, from clientID: UUID) {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
        guard let cmd = RemoteCommandDecoder.insert(from: data) else {
            sendAck(id: nil, ok: false, reason: RemoteRejectReason.malformed, to: clientID); return
        }
        guard authorizeWrite(id: cmd.id, from: clientID) else { return }
        // validateLoadPath is pure (no I/O) — fail-fast before spawning the task.
        if let reason = validateLoadPath(cmd.entry.path) {
            sendAck(id: cmd.id, ok: false, reason: reason, to: clientID); return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Build the single entry (one metadata read).
            let entry = await self.buildEntry(from: cmd.entry)
            // A1: re-assert auth/accept after the await.
            guard self.authorizeWrite(id: cmd.id, from: clientID) else { return }
            self.appState.ensureBuiltInPlayerActive()
            // Check position against the current setlist state at mutation time.
            let count = self.appState.setlist.entries.count
            guard cmd.at >= self.appState.setlist.firstQueuedIndex, cmd.at <= count else {
                self.sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.immutablePosition, to: clientID); return
            }
            self.appState.setlist.insert([entry], atIndex: cmd.at)
            self.sendAck(id: cmd.id, ok: true,
                         resolved: [.init(clientRef: cmd.entry.clientRef, entryId: entry.id.uuidString)],
                         to: clientID)
        }
    }

    private func handleSetlistRemove(data: Data, from clientID: UUID) {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
        guard let cmd = RemoteCommandDecoder.remove(from: data) else {
            sendAck(id: nil, ok: false, reason: RemoteRejectReason.malformed, to: clientID); return
        }
        guard authorizeWrite(id: cmd.id, from: clientID) else { return }
        guard let uuid = UUID(uuidString: cmd.entryId),
              appState.setlist.entries.contains(where: { $0.id == uuid }) else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.unknownEntry, to: clientID); return
        }
        guard appState.setlist.isQueuedEntry(uuid) else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.entryImmutable, to: clientID); return
        }
        appState.setlist.remove(ids: [uuid])
        sendAck(id: cmd.id, ok: true, to: clientID)
    }

    private func handleSetlistMove(data: Data, from clientID: UUID) {
        guard isAcceptingClients, authenticatedClients.contains(clientID) else { return }
        guard let cmd = RemoteCommandDecoder.move(from: data) else {
            sendAck(id: nil, ok: false, reason: RemoteRejectReason.malformed, to: clientID); return
        }
        guard authorizeWrite(id: cmd.id, from: clientID) else { return }
        guard let uuid = UUID(uuidString: cmd.entryId),
              appState.setlist.entries.contains(where: { $0.id == uuid }) else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.unknownEntry, to: clientID); return
        }
        guard appState.setlist.isQueuedEntry(uuid) else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.entryImmutable, to: clientID); return
        }
        let count = appState.setlist.entries.count
        guard cmd.toIndex >= appState.setlist.firstQueuedIndex, cmd.toIndex < count else {
            sendAck(id: cmd.id, ok: false, reason: RemoteRejectReason.immutablePosition, to: clientID); return
        }
        appState.setlist.moveEntry(id: uuid, toIndex: cmd.toIndex)
        sendAck(id: cmd.id, ok: true, to: clientID)
    }

    /// Validates + builds a batch of load entries (used by loadSetlist/replaceFuture). Returns the
    /// built entries plus the resolved/failed lists for the ack.
    private func buildEntries(_ entries: [RemoteLoadEntry]) async
        -> (built: [SetlistEntry], resolved: [RemoteAck.Resolved], failed: [RemoteAck.Failed]) {
        var built: [SetlistEntry] = []
        var resolved: [RemoteAck.Resolved] = []
        var failed: [RemoteAck.Failed] = []
        for le in entries {
            if let reason = validateLoadPath(le.path) {
                failed.append(.init(clientRef: le.clientRef, reason: reason))
                continue
            }
            let entry = await buildEntry(from: le)
            built.append(entry)
            resolved.append(.init(clientRef: le.clientRef, entryId: entry.id.uuidString))
        }
        return (built, resolved, failed)
    }

    private func handleAuth(pin: String?, from clientID: UUID) {
        guard let transport else { return }
        // If paused, refuse auth — client will see the disconnect and retry later.
        guard isAcceptingClients else {
            transport.disconnect(clientID)
            return
        }
        // Brute-force throttle: while locked, refuse without even checking the
        // PIN. Global on purpose — reconnecting clients get fresh UUIDs, so a
        // per-client limit would be trivially bypassed.
        let now = ProcessInfo.processInfo.systemUptime
        guard !pinLimiter.isLocked(at: now) else {
            let nack = #"{"type":"auth","ok":false,"reason":"locked"}"#
            transport.send(nack, to: clientID)
            transport.disconnect(clientID)
            return
        }
        let expected = settings.remoteControlPin
        guard let pin, !expected.isEmpty, pin == expected else {
            pinLimiter.registerFailure(at: now)
            let nack = #"{"type":"auth","ok":false}"#
            transport.send(nack, to: clientID)
            transport.disconnect(clientID)
            return
        }
        pinLimiter.registerSuccess()
        authenticatedClients.insert(clientID)
        let ack = #"{"type":"auth","ok":true}"#
        transport.send(ack, to: clientID)
        if let snapshot = snapshotJSON() {
            transport.send(snapshot, to: clientID)
        }
    }

    private func handleSet(field: String?, value: Any?, from clientID: UUID) {
        guard let field, let value else { return }
        switch field {
        case "mainVolume":
            if let v = (value as? Double) ?? (value as? Int).map(Double.init) {
                appState.syncVolume(Float(max(0.0, min(1.0, v))))
            }
        case "cortinaVolumeDb":
            if let v = (value as? Double) ?? (value as? Int).map(Double.init) {
                settings.cortinaVolumeReductionDb = max(-10.0, min(0.0, v))
            }
        case "replayGain.mode":
            if let raw = value as? String, let mode = ReplayGainMode(rawValue: raw) {
                settings.replayGainMode = mode
            }
        case "replayGain.preampDb":
            if let v = (value as? Double) ?? (value as? Int).map(Double.init) {
                settings.replayGainPreampDb = Float(max(-12.0, min(6.0, v)))
            }
        case "replayGain.preventClipping":
            if let b = value as? Bool {
                settings.replayGainPreventClipping = b
            }
        case "replayGain.targetLufs":
            if let v = (value as? Double) ?? (value as? Int).map(Double.init) {
                settings.replayGainTargetLufs = Float(max(-23.0, min(-14.0, v)))
            }
        default:
            break
        }
    }
}

// MARK: - RemoteTransportDelegate

extension RemoteControlBridge: RemoteTransportDelegate {
    nonisolated func transport(_ transport: RemoteTransport, didConnect clientID: UUID) {
        Task { @MainActor in
            // Drop new connections immediately when paused — the web client's
            // reconnect loop will retry, and once resumed the next attempt succeeds.
            guard self.isAcceptingClients else {
                transport.disconnect(clientID)
                return
            }
            transport.send(self.helloJSON(), to: clientID)
        }
    }

    nonisolated func transport(_ transport: RemoteTransport, didDisconnect clientID: UUID) {
        Task { @MainActor in
            self.authenticatedClients.remove(clientID)
        }
    }

    nonisolated func transport(_ transport: RemoteTransport, didReceiveText text: String, from clientID: UUID) {
        Task { @MainActor in
            self.handle(message: text, from: clientID)
        }
    }
}
