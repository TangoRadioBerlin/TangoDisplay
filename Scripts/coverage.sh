#!/usr/bin/env bash
# Code coverage for TangoDisplayCore via the lightweight test runner.
# No Xcode/XCTest needed — instruments the executable test target with the
# Swift profiler and reports with llvm-cov.
#
# Usage: bash Scripts/coverage.sh [--show]
#   --show   also print line-by-line coverage (llvm-cov show), not just the summary
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

BIN=".build/debug/TangoDisplayTests"
COV_DIR=".build/coverage"
PROFRAW="$COV_DIR/tests.profraw"
PROFDATA="$COV_DIR/tests.profdata"

mkdir -p "$COV_DIR"

echo "== Build (instrumented) =="
swift build --product TangoDisplayTests \
  -Xswiftc -profile-generate -Xswiftc -profile-coverage-mapping

echo "== Run tests =="
LLVM_PROFILE_FILE="$PROFRAW" "$BIN"

echo "== Merge profile =="
xcrun llvm-profdata merge -sparse "$PROFRAW" -o "$PROFDATA"

echo ""
echo "== Coverage report (Sources/TangoDisplayCore) =="
xcrun llvm-cov report "$BIN" \
  -instr-profile="$PROFDATA" \
  -ignore-filename-regex='(Tests|\.build)/' \
  Sources/TangoDisplayCore

if [[ "${1:-}" == "--show" ]]; then
  echo ""
  echo "== Line-by-line (uncovered regions) =="
  xcrun llvm-cov show "$BIN" \
    -instr-profile="$PROFDATA" \
    -ignore-filename-regex='(Tests|\.build)/' \
    -show-line-counts-or-regions \
    Sources/TangoDisplayCore
fi
