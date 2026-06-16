# TangoDisplay Remote Control — Protocol v2 (Slice 1)

TangoDisplay exposes a small LAN WebSocket remote on **port 4747** (`ws://<host>:4747/ws`, also
discoverable via Bonjour `_http._tcp` as "TangoDisplay Remote"). v1 drives volume / cortina volume /
ReplayGain and reads now-playing state. **v2** adds, backward-compatibly, capability negotiation, a
full setlist broadcast, and transport control so an external planner (e.g. MilongaForge) can drive a
milonga that TangoDisplay plays with its own engine (fades, EQ, ReplayGain, auto-gap, cortinas).

This document specifies **Slice 1**. `loadSetlist` and ordering edits (`setlist.insert/remove/move`)
are **deferred** to later slices (see *Deferred* below).

> All messages are JSON text frames with a `type` field. No TLS — intended for trusted LANs only.

## Compatibility

- Only **new `type`s and optional fields** are added. v1 clients (the built-in phone web UI) ignore
  them and keep working unchanged.
- The PIN handshake and the global brute-force lockout are **unchanged**.
- Connection/frame limits are unchanged (≤16 clients, 16 KiB headers, 1 MiB frames).

## Controller scope (authorization)

Controller commands (`transport`, `playEntry`) and the `state.setlist[]` broadcast require the DJ to
enable **"Allow remote setlist control"** (Player ▸ Setlist Remote; off by default). When off, the
remote behaves exactly like v1 (read + volume/ReplayGain) and `hello.capabilities` is empty.
Authentication (the 4-digit PIN) is still required for everything.

## Handshake

On connect the server sends:

```json
{ "type": "hello", "needsAuth": true, "protocolVersion": 2, "capabilities": ["transport", "setlist.read"] }
```

- `protocolVersion`: integer, currently `2`.
- `capabilities`: subset of `["transport","setlist.read"]`; **empty** unless controller scope is on.
- v1 servers omit `protocolVersion`/`capabilities` → clients must treat their absence as v1.

Authenticate (unchanged from v1):

```json
→ { "type": "auth", "pin": "1234" }
← { "type": "auth", "ok": true }                       // success, followed by a state snapshot
← { "type": "auth", "ok": false }                      // wrong PIN → server disconnects
← { "type": "auth", "ok": false, "reason": "locked" }  // brute-force lockout → disconnect
```

## State broadcast

The existing throttled (~100 ms) `state` message gains an optional `setlist` array (present only
under controller scope). All v1 fields are unchanged.

```json
{
  "type": "state",
  "mainVolume": 0.75,
  "cortinaVolumeDb": -3.5,
  "replayGain": { "mode": "auto", "preampDb": 0.0, "preventClipping": true, "targetLufs": -18.0 },
  "nowPlaying": {
    "playerState": "playing", "displayMode": "playing", "snapshotAt": 1718572345000,
    "title": "...", "artist": "...", "genre": "Tango",
    "tanda": { "current": 2, "total": 4 }, "elapsedSec": 45.3, "durationSec": 193.2
  },
  "setlist": [
    {
      "entryId": "F1E2…",          // stable server UUID — use for playEntry / diffing
      "clientRef": null,            // opaque controller id, echoed verbatim (null until loadSetlist)
      "title": "...", "artist": "...", "genre": "Tango",
      "isCortina": false,
      "state": "queued",            // queued | playing | paused | played
      "durationSec": 173.0,
      "isPerformance": false
    }
  ]
}
```

`setlist[]` carries **no file paths**. `entryId` is stable across reorders and app restarts.

## Transport

```json
→ { "type": "transport", "id": "c-12", "action": "play", "fadeSec": 4.0 }
← { "type": "ack", "id": "c-12", "ok": true }
```

- `action` ∈ `play | pause | resume | next | previous | stop | fadeAndStop | fadeAndContinue`.
  - `play`/`resume` start/continue playback; `pause` uses the app's pause-arm behaviour;
    `next`/`previous` skip; `stop` stops; `fadeAndStop`/`fadeAndContinue` apply the configured fade
    (these act during a cortina, matching the in-app controls).
- `id` (optional): correlation id echoed in the `ack`.
- `fadeSec` (optional): reserved; Slice 1 uses the app's configured fade duration.
- If another player source is active, the server **auto-switches to the built-in player** before
  applying (transport is only controllable there).

## Play a specific entry

```json
→ { "type": "playEntry", "id": "c-13", "entryId": "F1E2…" }
← { "type": "ack", "id": "c-13", "ok": true }
← { "type": "ack", "id": "c-13", "ok": false, "rejected": { "reason": "unknownEntry" } }
```

## Acks & reasons

Every controller command is answered with `ack{ id?, ok }`. Rejections carry
`rejected.reason`, one of:

- `controllerDisabled` — "Allow remote setlist control" is off.
- `unknownEntry` — `playEntry.entryId` not found in the current setlist.
- `malformed` — the command body failed to parse (e.g. unknown `action`).

## Deferred (later slices)

- `loadSetlist { mode: replace|append, entries:[{clientRef, path, title, artist, kind, tandaRef}] }`
  — introduces the local-file-path surface (needs path validation + audio-type checks);
  `clientRef` will then be echoed in `state.setlist[]`.
- Ordering edits `setlist.insert | setlist.remove | setlist.move` over the **future** (queued) part;
  playing/played entries are immutable and edits to them are rejected.
