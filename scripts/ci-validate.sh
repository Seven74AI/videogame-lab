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
echo "→ Running headless validation..."

# Run Godot headless, capture both stdout and stderr
GODOT_SILENCE_ROOT_WARNING=1
export GODOT_SILENCE_ROOT_WARNING

OUTPUT=$("$GODOT" --headless --quit --path "$PROJECT_PATH" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

# Check for parse errors, load failures, or script errors
ERRORS=$(echo "$OUTPUT" | grep -c -i -E '(ERROR:|SCRIPT ERROR|Parse Error|Failed to load|CRASH)') || true

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
echo "════════════════════════════════════════════════════════════"
echo "  VALIDATION PASSED — Project loads without errors"
echo "════════════════════════════════════════════════════════════"
exit 0
