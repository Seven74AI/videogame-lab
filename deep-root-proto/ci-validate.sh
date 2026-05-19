#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ci-validate.sh — CI validation for deep-root-proto
# Runs GUT test suite with coverage and enforces 80% threshold.
# Exit 0 = all pass, Exit 1 = failures or coverage below threshold
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"

echo "════════════════════════════════════════════════════════════"
echo " CI Validate — deep-root-proto"
echo " Coverage threshold: ${COVERAGE_THRESHOLD}%"
echo "════════════════════════════════════════════════════════════"

# ── 1. Run GUT test suite with coverage ────────────────────────
echo ""
echo "[1/3] Running GUT test suite with coverage..."
echo ""

godot4 --headless --path "$SCRIPT_DIR" \
  -s addons/gut/gut_cmdln.gd \
  -gconfig=.gutconfig.json \
  -gcover 2>&1

GODOT_EXIT=$?
if [ $GODOT_EXIT -ne 0 ]; then
  echo ""
  echo "✗ TESTS FAILED (exit code $GODOT_EXIT)"
  exit 1
fi

echo ""
echo "✓ All tests passed"

# ── 2. Parse coverage JSON ─────────────────────────────────────
echo ""
echo "[2/3] Checking coverage..."

COVERAGE_JSON=""
# GUT 9.x outputs to coverage/json/coverage.json
if [ -f "$SCRIPT_DIR/coverage/json/coverage.json" ]; then
  COVERAGE_JSON="$SCRIPT_DIR/coverage/json/coverage.json"
# GUT 7.x and earlier output to coverage.json in project root
elif [ -f "$SCRIPT_DIR/coverage.json" ]; then
  COVERAGE_JSON="$SCRIPT_DIR/coverage.json"
fi

if [ -z "$COVERAGE_JSON" ]; then
  echo "✗ No coverage JSON found (checked coverage/json/coverage.json and coverage.json)"
  exit 1
fi

echo "  Coverage data: $COVERAGE_JSON"

# ── 3. Enforce coverage threshold ──────────────────────────────
echo ""
echo "[3/3] Enforcing ${COVERAGE_THRESHOLD}% coverage threshold..."

LINE_PCT=$(python3 -c "
import json, sys
with open('$COVERAGE_JSON') as f:
    d = json.load(f)
# GUT 9.x format: d['totals']['line_percent']
# Fallback: d['line_percent']
if 'totals' in d and 'line_percent' in d['totals']:
    pct = d['totals']['line_percent']
elif 'line_percent' in d:
    pct = d['line_percent']
else:
    print('UNKNOWN', file=sys.stderr)
    sys.exit(1)
print(pct)
" 2>&1)

if [ "$?" != "0" ] || [ "$LINE_PCT" = "UNKNOWN" ]; then
  echo "✗ Could not parse line percent from coverage JSON"
  exit 1
fi

echo "  Line coverage: ${LINE_PCT}%"

COV_OK=$(python3 -c "print(1 if float('$LINE_PCT') >= $COVERAGE_THRESHOLD else 0)")
if [ "$COV_OK" = "0" ]; then
  echo ""
  echo "✗ COVERAGE FAILED: ${LINE_PCT}% < ${COVERAGE_THRESHOLD}%"
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo " ✓ CI VALIDATE PASSED"
echo "   All tests passing, coverage ${LINE_PCT}% ≥ ${COVERAGE_THRESHOLD}%"
echo "════════════════════════════════════════════════════════════"
exit 0
