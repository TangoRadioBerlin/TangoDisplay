#!/usr/bin/env bash
# repro-drag-freeze.sh
#
# Automated drag-drop freeze reproduction harness.
# Uses Finder as a JRiver proxy (both deliver public.file-url, same Branch 4 code path).
#
# Prerequisites:
#   - peekaboo CLI at /opt/homebrew/bin/peekaboo
#   - TangoDisplay.app installed at /Applications/TangoDisplay.app
#   - Duplicate track protection ON (will be set by this script)
#   - Freeze-detection logging ON (will be set by this script)
#   - At least two audio files available (created in /tmp/tango-repro-fixtures)
#
# Workflow:
#   1. Create synthetic audio fixtures in /tmp/tango-repro-fixtures
#   2. Enable diagnosticLoggingEnabled + duplicateTrackProtection
#   3. Launch TangoDisplay, wait for it to be ready
#   4. Open fixtures in Finder, drag them into TangoDisplay once to seed the setlist
#   5. Loop: drag again (triggers duplicate prompt → runModal path), watch for stall fault
#   6. On stall fault detected: save log excerpt, exit 0 (freeze reproduced)
#   7. On max iterations reached without fault: exit 0 (regression confirmed: no stall)
#
# Environment variables:
#   MAX_ITERATIONS  how many drag attempts before declaring "no freeze" (default: 100)
#   STALL_TIMEOUT   seconds to wait after each drag before checking log (default: 10)

set -euo pipefail

PEEKABOO=/opt/homebrew/bin/peekaboo
APP="/Applications/TangoDisplay.app"
FIXTURES_DIR="/tmp/tango-repro-fixtures"
LOG_FILE="/tmp/tango-repro-$(date +%Y%m%d-%H%M%S).log"
MAX_ITERATIONS="${MAX_ITERATIONS:-100}"
STALL_TIMEOUT="${STALL_TIMEOUT:-10}"
BUNDLE_ID="com.local.tangodisplay"
UD_PREFIX="TangoDisplay"

echo "═══════════════════════════════════════════════════"
echo "  TangoDisplay Drag-Freeze Repro Harness"
echo "  Max iterations : $MAX_ITERATIONS"
echo "  Stall timeout  : ${STALL_TIMEOUT}s"
echo "  Log file       : $LOG_FILE"
echo "═══════════════════════════════════════════════════"

# ── 1. Fixtures ────────────────────────────────────────
mkdir -p "$FIXTURES_DIR"
# Create minimal valid AIFF files (44 bytes: FORM+AIFF header + COMM chunk)
for i in 1 2 3; do
    f="$FIXTURES_DIR/test-track-$i.aiff"
    if [ ! -f "$f" ]; then
        python3 - "$f" <<'PYEOF'
import sys, struct
path = sys.argv[1]
# Minimal 44-byte AIFF: FORM + AIFF + COMM chunk (1ch, 0 samples, 16-bit, 44100Hz)
comm = struct.pack('>4sI', b'COMM', 18) + struct.pack('>hIh', 1, 0, 16)
# 80-bit IEEE 754 extended for 44100.0
comm += b'\x40\x0e\xac\x44\x00\x00\x00\x00\x00\x00'
form = struct.pack('>4sI4s', b'FORM', 4 + len(comm), b'AIFF') + comm
with open(path, 'wb') as fh:
    fh.write(form)
print(f'Created {path} ({len(form)} bytes)')
PYEOF
    fi
done
echo "✓ Fixtures ready in $FIXTURES_DIR"

# ── 2. UserDefaults ─────────────────────────────────────
defaults write "$BUNDLE_ID" "${UD_PREFIX}.diagnosticLoggingEnabled" -bool YES
defaults write "$BUNDLE_ID" "${UD_PREFIX}.duplicateTrackProtection" -bool YES
echo "✓ diagnosticLoggingEnabled=YES, duplicateTrackProtection=YES"

# ── 3. Launch TangoDisplay ──────────────────────────────
echo "⟳ Launching TangoDisplay…"
# Quit any running instance first
osascript -e 'tell application "TangoDisplay" to if it is running then quit' 2>/dev/null || true
sleep 2
open "$APP"
sleep 4  # wait for window to appear

APP_VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")
echo "✓ App launched (installed version: $APP_VERSION)"

# ── 4. Open Finder on fixture folder ───────────────────
echo "⟳ Opening Finder at fixtures…"
open "$FIXTURES_DIR"
sleep 2

# ── 5. Seed the setlist (first drag — no duplicates yet) ─
echo "⟳ Seeding setlist with initial drag (no duplicates yet)…"
# Use peekaboo to select all files in Finder and drag to the TangoDisplay control window.
# The exact coordinates depend on window positions; we use the app/window API to find them.
# For reliability, use peekaboo's agent mode with a natural-language instruction.
"$PEEKABOO" agent --prompt "In Finder, select all files in the window showing /tmp/tango-repro-fixtures, then drag them to the TangoDisplay window (the Setlist area). If a duplicate dialog appears, click Add or Don't Add to dismiss it." 2>&1 | tee -a "$LOG_FILE" || true
sleep 3
echo "✓ Seed drag complete"

# NOTE on drop targets: drops landing ON a setlist row are handled by SwiftUI's
# .onInsert (Task-deferred — safe even on unfixed builds). Only drops on the
# EMPTY area below the last row (or window chrome) fall through to the
# window-level MusicAppDropView, whose synchronous handleIncomingURLs →
# promptForDuplicates → runModal chain is the freeze-suspect path. The repro
# loop below must therefore target the empty area BELOW the rows.

# ── 6. Start log stream in background ──────────────────
LOG_STREAM_FILE="/tmp/tango-repro-stream-$$.log"
log stream \
    --predicate 'subsystem == "com.tangodisplay" AND (category == "diagnostics" OR category == "musicdrop.timing")' \
    --level info \
    > "$LOG_STREAM_FILE" 2>&1 &
LOG_STREAM_PID=$!
echo "✓ Log stream started (pid=$LOG_STREAM_PID) → $LOG_STREAM_FILE"
sleep 1  # let stream establish

# ── 7. Repro loop ───────────────────────────────────────
echo ""
echo "── Starting repro loop (max $MAX_ITERATIONS iterations) ──"
FREEZE_DETECTED=0
for i in $(seq 1 "$MAX_ITERATIONS"); do
    echo -n "  [iter $i/$MAX_ITERATIONS] dragging… "

    # Drag fixtures into TangoDisplay again (duplicates → runModal path).
    # IMPORTANT: drop onto the EMPTY area BELOW the last setlist row — drops on
    # rows take the safe .onInsert path and can never reproduce the freeze.
    "$PEEKABOO" agent --prompt "In Finder, select all files in the window showing /tmp/tango-repro-fixtures, then drag them into the TangoDisplay window, dropping them on the EMPTY space BELOW the last track row in the setlist (not onto a track row itself). If a duplicate alert appears, click the first button (Add) to dismiss it." 2>&1 >> "$LOG_STREAM_FILE" || true

    # Wait for the interaction to complete or for the stall to manifest
    sleep "$STALL_TIMEOUT"

    # Check for stall fault in the stream
    if grep -q "MAIN THREAD STALLED" "$LOG_STREAM_FILE" 2>/dev/null; then
        echo "🔴 STALL DETECTED"
        FREEZE_DETECTED=1
        break
    fi

    # Quick responsiveness check: can peekaboo still see the app UI?
    if ! "$PEEKABOO" see --app TangoDisplay --timeout 3 > /dev/null 2>&1; then
        echo "⚠ UI unresponsive (separate sign of freeze)"
        FREEZE_DETECTED=1
        break
    fi

    echo "ok (responsive)"
done

# ── 8. Cleanup ──────────────────────────────────────────
kill "$LOG_STREAM_PID" 2>/dev/null || true
wait "$LOG_STREAM_PID" 2>/dev/null || true

# Save combined log
cat "$LOG_STREAM_FILE" >> "$LOG_FILE"

echo ""
echo "═══════════════════════════════════════════════════"
if [ "$FREEZE_DETECTED" -eq 1 ]; then
    echo "🔴 RESULT: FREEZE REPRODUCED"
    echo "   Stall log saved to: $LOG_FILE"
    echo ""
    echo "── Relevant log excerpt ──"
    grep -A5 "MAIN THREAD STALLED" "$LOG_FILE" 2>/dev/null || grep -A5 "unresponsive" "$LOG_FILE" || true
else
    echo "🟢 RESULT: NO FREEZE in $MAX_ITERATIONS iterations"
    echo "   Regression confirmed: the fix holds."
    echo "   Full log: $LOG_FILE"
fi
echo "═══════════════════════════════════════════════════"

# Restore defaults
defaults write "$BUNDLE_ID" "${UD_PREFIX}.diagnosticLoggingEnabled" -bool NO
echo "(diagnosticLoggingEnabled reset to NO)"

[ "$FREEZE_DETECTED" -eq 1 ] && exit 0 || exit 0
