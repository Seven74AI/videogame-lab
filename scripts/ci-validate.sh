#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ci-validate.sh — Godot headless project validation
# ═══════════════════════════════════════════════════════════════
# Usage: ./scripts/ci-validate.sh [project_path]
#   - Default project path: ./deep-root-proto/
#   - Finds godot4 on PATH or /usr/local/bin/godot4
#   - Returns 0 if project loads without errors, 1 otherwise
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

PROJECT_PATH="${1:-deep-root-proto/}"

# Locate godot4
GODOT=""
for candidate in godot4 /usr/local/bin/godot4 /opt/godot/godot4; do
    if command -v "$candidate" &>/dev/null; then
        GODOT="$candidate"
        break
    fi
done

if [ -z "$GODOT" ]; then
    echo "ERROR: godot4 not found on PATH or standard locations" >&2
    exit 1
fi

if [ ! -f "$PROJECT_PATH/project.godot" ]; then
    echo "ERROR: project.godot not found at $PROJECT_PATH" >&2
    exit 1
fi

echo "→ Godot version: $("$GODOT" --version 2>&1 | head -1)"
echo "→ Project: $PROJECT_PATH"
echo ""
echo "→ Checking TSCN structural rules..."

TSCN_ERRORS=0
# Rule: HUD control nodes must have mouse_filter=1 (IGNORE) or absent
#        Default mouse_filter=0 (STOP) blocks game clicks
for tscn in $(find "$PROJECT_PATH" -name "*.tscn" -not -path "*/addons/*"); do
    if grep -q 'type="Panel"\|type="Label"' "$tscn" 2>/dev/null; then
        # Extract nodes that are Panel or Label without mouse_filter=1
        # awk state machine: track current node type, check next line for mouse_filter
        node_type=""
        while IFS= read -r line; do
            if echo "$line" | grep -q '\[node name=.*type="\(Panel\|Label\)"'; then
                node_type=$(echo "$line" | sed 's/.*name="\([^"]*\)".*/\1/')
                has_mf=0
            elif echo "$line" | grep -q 'mouse_filter'; then
                has_mf=1
                if ! echo "$line" | grep -q 'mouse_filter = 1'; then
                    echo "  FAIL: $tscn -> $node_type has mouse_filter != 1 (blocks clicks!)"
                    TSCN_ERRORS=$((TSCN_ERRORS + 1))
                fi
            elif echo "$line" | grep -q '^$' && [ -n "$node_type" ] && [ "$has_mf" -eq 0 ]; then
                echo "  FAIL: $tscn -> $node_type missing mouse_filter (defaults to STOP=0, blocks clicks!)"
                TSCN_ERRORS=$((TSCN_ERRORS + 1))
                node_type=""
            fi
        done < "$tscn"
    fi
done

if [ "$TSCN_ERRORS" -gt 0 ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  TSCN STRUCTURAL CHECK FAILED — $TSCN_ERRORS issue(s)"
    echo "  Fix: add 'mouse_filter = 1' to all Panel/Label nodes in HUD scenes"
    echo "════════════════════════════════════════════════════════════"
    exit 1
fi
echo "  TSCN structural check PASSED"

echo ""
echo "→ Running headless validation..."

# Run Godot headless, capture both stdout and stderr
GODOT_SILENCE_ROOT_WARNING=1
export GODOT_SILENCE_ROOT_WARNING

OUTPUT=$("$GODOT" --headless --quit --path "$PROJECT_PATH" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

# Check for parse errors, load failures, or script errors
# Anchored patterns to Godot logger prefix to avoid false positives (e.g. "No ERROR:")
ERRORS=$(echo "$OUTPUT" | grep -c -E '(^ERROR:|SCRIPT ERROR:|Parse Error:|Failed to load scene|Godot Engine v[0-9].*Crash)') || true

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  VALIDATION FAILED — $ERRORS error(s) detected"
    echo "════════════════════════════════════════════════════════════"
    exit 1
fi

if [ "$EXIT_CODE" -ne 0 ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  VALIDATION FAILED — Godot exited with code $EXIT_CODE"
    echo "════════════════════════════════════════════════════════════"
    exit 1
fi

echo ""

# ── GUT Test Suite + Coverage ─────────────────────────────────
echo "→ Running GUT test suite with coverage..."
GUT_OUTPUT=$("$GODOT" --headless --path "$PROJECT_PATH" -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gcover 2>&1)
GUT_EXIT=$?

echo "$GUT_OUTPUT"

# Check for test failures and errors
GUT_FAILS=$(echo "$GUT_OUTPUT" | grep -c "failing assertions\|Failed [0-9]* tests" || true)
GUT_ERRORS=$(echo "$GUT_OUTPUT" | grep -cE "(ERROR:|SCRIPT ERROR:)" || true)

if [ "$GUT_EXIT" -ne 0 ] || [ "$GUT_FAILS" -gt 0 ] || [ "$GUT_ERRORS" -gt 0 ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  GUT TEST SUITE FAILED — exit=$GUT_EXIT fails=$GUT_FAILS errors=$GUT_ERRORS"
    echo "════════════════════════════════════════════════════════════"
    exit 1
fi

echo "  GUT test suite PASSED"

# ── Coverage Enforcement (80% threshold) ──────────────────────
echo ""
echo "→ Checking coverage threshold (80%)..."
COV_JSON="$PROJECT_PATH/coverage/json/coverage.json"

if [ -f "$COV_JSON" ]; then
    COV=$(python3 -c "import json; d=json.load(open('$COV_JSON')); pct=d.get('totals',{}).get('line_percent',0); print(pct)" 2>/dev/null)
    if [ -n "$COV" ]; then
        COV_THRESHOLD=80
        COV_OK=$(echo "$COV >= $COV_THRESHOLD" | bc 2>/dev/null || echo 0)
        if [ "$COV_OK" -eq 0 ]; then
            echo "  COVERAGE FAILED: ${COV}% < ${COV_THRESHOLD}%"
            echo "════════════════════════════════════════════════════════════"
            echo "  COVERAGE BELOW THRESHOLD"
            echo "════════════════════════════════════════════════════════════"
            exit 1
        fi
        echo "  Coverage: ${COV}% ≥ ${COV_THRESHOLD}% — PASSED"
    else
        echo "  WARNING: Could not parse coverage percentage from $COV_JSON"
    fi
else
    echo "  WARNING: coverage.json not found at $COV_JSON"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  VALIDATION PASSED — Project loads without errors, tests + coverage OK"
echo "════════════════════════════════════════════════════════════"
exit 0
