# TangoDisplay Remote Control — Protocol v2 (Slices 1–2)

TangoDisplay exposes a small LAN WebSocket remote on **port 4747** (`ws://<host>:4747/ws`, also
discoverable via Bonjour `_http._tcp` as "TangoDisplay Remote"). v1 drives volume / cortina volume /
ReplayGain and reads now-playing state. **v2** adds, backward-compatibly, capability negotiation, a
full setlist broadcast, and transport control so an external planner (e.g. MilongaForge) can drive a
milonga that TangoDisplay plays with its own engine (fades, EQ, ReplayGain, auto-gap, cortinas).

This document specifies **Slice 1** (capability negotiation, setlist broadcast, transport —
implemented) and **Slice 2** (`loadSetlist` + ordering edits `setlist.insert/remove/move` —
proposed; see *Slice 2* below).

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

## Slice 2 — setlist loading & ordering edits

> **Status:** proposed (design for the next slice; Slice 1 above is implemented). Motivated by the
> MilongaForge planner (its ADR-033 / US-EXP-07): hand a planned milonga to TangoDisplay and then
> reconcile the running order. Adds **one capability** (`setlist.write`) and **four command types**;
> everything in Slice 1 is unchanged.

### Capability

When this slice is implemented **and** controller scope is on, `hello.capabilities` additionally
includes `"setlist.write"`:

```json
{ "type": "hello", "needsAuth": true, "protocolVersion": 2,
  "capabilities": ["transport", "setlist.read", "setlist.write"] }
```

A controller MUST check for `"setlist.write"` before sending the commands below; its absence means
the server is Slice-1-only (or controller scope is off), and these commands would be rejected with
`controllerDisabled`.

### Load entry (controller → server)

`loadSetlist` and `setlist.insert` carry **load entries** — the only place file paths enter the
protocol:

```json
{
  "clientRef": "recording:abc#t1",            // opaque, required; echoed verbatim in state.setlist[]
  "path": "/Users/dj/Music/.../track.flac",   // absolute local file path on the TangoDisplay host
  "title": "La cumparsita",                    // optional; falls back to the file's tags
  "artist": "Carlos Di Sarli",                 // optional; falls back to the file's tags
  "isCortina": false,                          // optional, default false; maps to state.setlist[].isCortina
  "tandaRef": "t1"                             // optional opaque grouping hint, echoed
}
```

- `path` is validated server-side: it must be an existing, readable, regular file of a supported
  audio type. Directories, URLs, and unsupported types are refused (per entry).
- `title`/`artist`/`isCortina` are display hints; if omitted the server uses the file's own tags
  (the same path as drag-and-drop import).
- The server assigns a stable `entryId` (UUID) per loaded entry and echoes the `clientRef` in
  subsequent `state.setlist[]` broadcasts (replacing the `null` carried by drag-and-drop entries).

### loadSetlist

```json
→ { "type": "loadSetlist", "id": "c-20", "mode": "replace",
    "entries": [ { "clientRef": "recording:abc#t1", "path": "/Users/dj/Music/a.flac",
                   "title": "La cumparsita", "artist": "Di Sarli", "isCortina": false, "tandaRef": "t1" } ] }
← { "type": "ack", "id": "c-20", "ok": true,
    "resolved": [ { "clientRef": "recording:abc#t1", "entryId": "9F0A…" } ],
    "failed":   [ { "clientRef": "recording:xyz#t1", "reason": "fileNotFound" } ] }
```

- `mode`:
  - `"append"` — add `entries` to the **end** of the setlist.
  - `"replace"` — clear the **future (queued)** part and load `entries` after the playing/played
    region. The playing entry and all played entries are **never** touched.
- **Partial success:** entries whose path fails validation appear in `failed[]` (each with a
  `reason`); all valid entries still load and appear in `resolved[]` paired with their `entryId`.
  `ack.ok` is `true` when the request was well-formed and authorized (an empty `resolved[]` with a
  populated `failed[]` is allowed).
- A fresh `state` broadcast follows on success.

### Ordering edits (queued region only)

All three edit the **queued** region; the playing entry and played entries are immutable.

```json
→ { "type": "setlist.insert", "id": "c-21", "at": 5, "entry": { "...": "a load entry (see above)" } }
← { "type": "ack", "id": "c-21", "ok": true, "resolved": [ { "clientRef": "…", "entryId": "…" } ] }

→ { "type": "setlist.remove", "id": "c-22", "entryId": "9F0A…" }
← { "type": "ack", "id": "c-22", "ok": true }

→ { "type": "setlist.move",   "id": "c-23", "entryId": "9F0A…", "toIndex": 9 }
← { "type": "ack", "id": "c-23", "ok": true }
```

- `at` / `toIndex` are 0-based indices into the **full** setlist but must address a position **inside
  the queued region** (after the playing entry). An index in the playing/played region is rejected
  with `immutablePosition`.
- `setlist.remove` / `setlist.move` targeting a `playing` or `played` entry → `entryImmutable`.
- `setlist.insert.entry` is a load entry, so it can also produce a path `reason` (e.g. `fileNotFound`).
- Each successful edit is followed by a `state` broadcast; controllers reconcile against
  `state.setlist[]` (matching on `entryId`/`clientRef`) rather than assuming their local order won.

### Optional: bulk replace of the queued region

For a one-shot reconcile a controller MAY send the desired future order and let the server compute the
minimal diff:

```json
→ { "type": "setlist.replaceFuture", "id": "c-24", "entries": [ { "...": "load entries, in order" } ] }
← { "type": "ack", "id": "c-24", "ok": true, "resolved": [ … ], "failed": [ … ] }
```

The server keeps the playing/played region intact and rewrites only the queued part. Servers that do
not implement this MAY reject it with `malformed`; the controller then falls back to
insert/remove/move.

### Additional rejection reasons (extending the Slice-1 list)

- `entryImmutable` — target entry is currently playing or already played.
- `immutablePosition` — `at`/`toIndex` falls in the playing/played region.
- `fileNotFound` — `path` does not exist.
- `unreadable` — `path` exists but is not a readable regular file.
- `unsupportedType` — `path` is not a supported audio file.
- `pathNotAllowed` — `path` rejected by the server's path policy (e.g. not absolute).

(`controllerDisabled`, `unknownEntry`, and `malformed` are as defined for Slice 1.)

### Ordering / source-of-truth (recap)

The playing+played region is authoritative on the TangoDisplay side and immutable to the controller.
The queued region is controller-led, but if the DJ reorders it locally the next `state` broadcast
reflects that; a controller diffs and surfaces a hint instead of blindly re-pushing. This mirrors
Slice 1's "no paths in `state`, stable `entryId`" contract.

### Security / platform notes

- Paths are **local absolute paths on the TangoDisplay host**; the simplest deployment is the planner
  and TangoDisplay on the **same Mac**. No cross-host path translation or streaming in this slice.
- Path validation MUST reject anything that is not an existing, readable audio file. The remote stays
  **LAN-only, PIN-gated**, and the controller-scope toggle continues to apply.
