#!/usr/bin/env bash
# tests/shell/test_asset_wrapper.sh
#
# Shell unit tests for tools/generate_asset.sh (the submodule wrapper).
#
# Tests use an in-process mock framework — no external test runner required.
# Run from project root:
#   bash tests/shell/test_asset_wrapper.sh
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER="$PROJECT_ROOT/tools/generate_asset.sh"
SUBMODULE_SCRIPT="$PROJECT_ROOT/vendor/game-dev-tools/src/generate_asset.sh"
INTERNAL_SCRIPT="$PROJECT_ROOT/tools/_generate_asset_internal.sh"
REMOVE_BG="$PROJECT_ROOT/tools/remove_bg.py"

# ---------------------------------------------------------------------------
# Minimal test framework
# ---------------------------------------------------------------------------

PASS=0
FAIL=0
_FAILURES=()

pass() { echo "  PASS  $1"; (( PASS++ )) || true; }
fail() { echo "  FAIL  $1"; (( FAIL++ )) || true; _FAILURES+=("$1"); }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$label"
  else
    fail "$label (expected: $(printf '%q' "$expected"), got: $(printf '%q' "$actual"))"
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  [[ -f "$path" ]] && pass "$label" || fail "$label (missing: $path)"
}

assert_executable() {
  local label="$1" path="$2"
  [[ -x "$path" ]] && pass "$label" || fail "$label (not executable: $path)"
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  [[ "$haystack" == *"$needle"* ]] && pass "$label" \
    || fail "$label (expected to contain: $(printf '%q' "$needle"))"
}

assert_exit_zero() {
  local label="$1" exit_code="$2"
  [[ "$exit_code" -eq 0 ]] && pass "$label" || fail "$label (exit code: $exit_code)"
}

assert_exit_nonzero() {
  local label="$1" exit_code="$2"
  [[ "$exit_code" -ne 0 ]] && pass "$label" || fail "$label (expected non-zero exit)"
}

# ---------------------------------------------------------------------------
# Test helpers: build a temporary project sandbox with mock scripts
# ---------------------------------------------------------------------------

# Creates a sandbox directory tree that mimics the project structure.
# Returns the sandbox root via stdout.
_make_sandbox() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/tools" "$tmp/assets/generated" "$tmp/vendor/game-dev-tools/src"
  # Copy real scripts into sandbox
  cp "$WRAPPER"   "$tmp/tools/generate_asset.sh"
  cp "$INTERNAL_SCRIPT" "$tmp/tools/_generate_asset_internal.sh" 2>/dev/null || true
  cp "$REMOVE_BG" "$tmp/tools/remove_bg.py" 2>/dev/null || true
  echo "$tmp"
}

# Write a mock generator script that records call details and optionally
# produces a fake "Saved: " line.
_write_mock_generator() {
  local path="$1" asset_type="${2:-sprite}" exit_code="${3:-0}" output_dir=""
  cat > "$path" <<MOCK
#!/usr/bin/env bash
set -euo pipefail
echo "MOCK_CALLED type=\${1:-} ASSET_OUTPUT_DIR=\${ASSET_OUTPUT_DIR:-}" >&2
echo "\$@" > "\${ASSET_OUTPUT_DIR:-.}/mock_args.txt"
# Simulate a saved sprite file
FAKE_FILE="\${ASSET_OUTPUT_DIR:-.}/sprite_mock_1234567890.png"
touch "\$FAKE_FILE"
echo "Saved: \$FAKE_FILE"
exit $exit_code
MOCK
  chmod +x "$path"
}

# ---------------------------------------------------------------------------
# Section 1 — File structure checks (no mocking needed)
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 1: File structure ==="

assert_file_exists    "wrapper script exists"            "$WRAPPER"
assert_executable     "wrapper script is executable"     "$WRAPPER"
assert_file_exists    "internal fallback exists"         "$INTERNAL_SCRIPT"
assert_executable     "internal fallback is executable"  "$INTERNAL_SCRIPT"
assert_file_exists    "remove_bg.py exists"              "$REMOVE_BG"

# Submodule: directory may not be populated in CI if `--init` was not run,
# but .gitmodules entry must exist.
GITMODULES="$PROJECT_ROOT/.gitmodules"
assert_file_exists    ".gitmodules exists"               "$GITMODULES"
SUBMODULE_ENTRY="$(grep -c "vendor/game-dev-tools" "$GITMODULES" || true)"
[[ "$SUBMODULE_ENTRY" -gt 0 ]] \
  && pass "vendor/game-dev-tools entry in .gitmodules" \
  || fail "vendor/game-dev-tools entry missing from .gitmodules"

if [[ -f "$SUBMODULE_SCRIPT" ]]; then
  assert_executable "submodule generate_asset.sh is executable" "$SUBMODULE_SCRIPT"
  assert_file_exists "submodule local_sprite_server.py exists" \
    "$PROJECT_ROOT/vendor/game-dev-tools/src/servers/local_sprite_server.py"
  assert_file_exists "submodule local_audio_server.py exists" \
    "$PROJECT_ROOT/vendor/game-dev-tools/src/servers/local_audio_server.py"
else
  echo "  SKIP  submodule content checks (submodule not initialised)"
fi

# ---------------------------------------------------------------------------
# Section 2 — Wrapper delegates to submodule when available
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 2: Submodule delegation ==="

SANDBOX="$(_make_sandbox)"
trap 'rm -rf "$SANDBOX"' EXIT

_write_mock_generator "$SANDBOX/vendor/game-dev-tools/src/generate_asset.sh" sprite 0

output="$(bash "$SANDBOX/tools/generate_asset.sh" sprite "test prompt" 2>&1)" || true
assert_contains "submodule mock was called"          "MOCK_CALLED"  "$output"
assert_contains "ASSET_OUTPUT_DIR forwarded"         "ASSET_OUTPUT_DIR=" "$output"

# Verify ASSET_OUTPUT_DIR points to project assets/generated
args_file="$SANDBOX/assets/generated/mock_args.txt"
[[ -f "$args_file" ]] \
  && pass "output landed in assets/generated/" \
  || fail "output did not land in assets/generated/ (args file missing)"

# ---------------------------------------------------------------------------
# Section 3 — remove_bg.py is called for sprites
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 3: Background removal for sprites ==="

SANDBOX2="$(_make_sandbox)"
trap 'rm -rf "$SANDBOX" "$SANDBOX2"' EXIT

_write_mock_generator "$SANDBOX2/vendor/game-dev-tools/src/generate_asset.sh" sprite 0

# Replace remove_bg.py with a sentinel that records it was called
cat > "$SANDBOX2/tools/remove_bg.py" <<'PY'
import sys, pathlib
pathlib.Path(sys.argv[1] + ".bg_stripped").touch()
PY

bash "$SANDBOX2/tools/generate_asset.sh" sprite "test prompt" >/dev/null 2>&1 || true
STRIPPED_COUNT="$(find "$SANDBOX2/assets/generated" -name "*.bg_stripped" | wc -l)"
[[ "$STRIPPED_COUNT" -gt 0 ]] \
  && pass "remove_bg.py called on generated sprite" \
  || fail "remove_bg.py was NOT called on generated sprite"

# SFX should NOT trigger background removal
SANDBOX3="$(_make_sandbox)"
trap 'rm -rf "$SANDBOX" "$SANDBOX2" "$SANDBOX3"' EXIT
_write_mock_generator "$SANDBOX3/vendor/game-dev-tools/src/generate_asset.sh" sfx 0
# Patch mock to save .wav instead
sed -i 's/sprite_mock_1234567890.png/sfx_mock_1234567890.wav/' \
  "$SANDBOX3/vendor/game-dev-tools/src/generate_asset.sh"
cat > "$SANDBOX3/tools/remove_bg.py" <<'PY'
import sys, pathlib
pathlib.Path(sys.argv[1] + ".bg_stripped").touch()
PY
bash "$SANDBOX3/tools/generate_asset.sh" sfx "test sound" >/dev/null 2>&1 || true
STRIPPED_SFX="$(find "$SANDBOX3/assets/generated" -name "*.bg_stripped" | wc -l)"
[[ "$STRIPPED_SFX" -eq 0 ]] \
  && pass "remove_bg.py NOT called for SFX" \
  || fail "remove_bg.py was incorrectly called for SFX"

# ---------------------------------------------------------------------------
# Section 4 — Fallback to internal script when submodule absent
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 4: Internal fallback when submodule absent ==="

SANDBOX4="$(_make_sandbox)"
trap 'rm -rf "$SANDBOX" "$SANDBOX2" "$SANDBOX3" "$SANDBOX4"' EXIT

# Do NOT create submodule script — only internal fallback
_write_mock_generator "$SANDBOX4/tools/_generate_asset_internal.sh" sprite 0

output4="$(bash "$SANDBOX4/tools/generate_asset.sh" sprite "test prompt" 2>&1)" || true
assert_contains "internal fallback called when submodule absent" "MOCK_CALLED" "$output4"

# ---------------------------------------------------------------------------
# Section 5 — FORCE_INTERNAL skips submodule
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 5: FORCE_INTERNAL flag ==="

SANDBOX5="$(_make_sandbox)"
trap 'rm -rf "$SANDBOX" "$SANDBOX2" "$SANDBOX3" "$SANDBOX4" "$SANDBOX5"' EXIT

# Write both scripts; submodule prints SUBMODULE_CALLED, internal prints INTERNAL_CALLED
cat > "$SANDBOX5/vendor/game-dev-tools/src/generate_asset.sh" <<'MOCK'
#!/usr/bin/env bash
echo "SUBMODULE_CALLED" >&2
touch "${ASSET_OUTPUT_DIR:-}/sprite_sub_1.png"
echo "Saved: ${ASSET_OUTPUT_DIR:-}/sprite_sub_1.png"
MOCK
chmod +x "$SANDBOX5/vendor/game-dev-tools/src/generate_asset.sh"

cat > "$SANDBOX5/tools/_generate_asset_internal.sh" <<'MOCK'
#!/usr/bin/env bash
echo "INTERNAL_CALLED" >&2
touch "${ASSET_OUTPUT_DIR:-}/sprite_int_1.png"
echo "Saved: ${ASSET_OUTPUT_DIR:-}/sprite_int_1.png"
MOCK
chmod +x "$SANDBOX5/tools/_generate_asset_internal.sh"

output5="$(FORCE_INTERNAL=1 bash "$SANDBOX5/tools/generate_asset.sh" sprite "test" 2>&1)" || true
assert_contains  "FORCE_INTERNAL uses internal script" "INTERNAL_CALLED"  "$output5"
case "$output5" in
  *SUBMODULE_CALLED*) fail "FORCE_INTERNAL still called submodule" ;;
  *) pass "FORCE_INTERNAL did not call submodule" ;;
esac

# ---------------------------------------------------------------------------
# Section 6 — All generators fail → exit non-zero with instructions
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 6: All generators absent \u2192 non-zero exit + help message ==="

SANDBOX6="$(_make_sandbox)"
trap 'rm -rf "$SANDBOX" "$SANDBOX2" "$SANDBOX3" "$SANDBOX4" "$SANDBOX5" "$SANDBOX6"' EXIT

# Remove both generator scripts so neither tier is available
rm -f "$SANDBOX6/tools/_generate_asset_internal.sh"
rm -rf "$SANDBOX6/vendor/game-dev-tools/src/generate_asset.sh"

output6="$(bash "$SANDBOX6/tools/generate_asset.sh" sprite "test" 2>&1)" && rc6=0 || rc6=$?
assert_exit_nonzero "exit non-zero when no generators available" "$rc6"
assert_contains     "error message mentions submodule init"      \
  "git submodule update --init" "$output6"

# ---------------------------------------------------------------------------
# Section 7 — SKIP_REMOVE_BG suppresses background removal
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 7: SKIP_REMOVE_BG suppresses removal ==="

SANDBOX7="$(_make_sandbox)"
trap 'rm -rf "$SANDBOX" "$SANDBOX2" "$SANDBOX3" "$SANDBOX4" "$SANDBOX5" "$SANDBOX6" "$SANDBOX7"' EXIT

_write_mock_generator "$SANDBOX7/vendor/game-dev-tools/src/generate_asset.sh" sprite 0
cat > "$SANDBOX7/tools/remove_bg.py" <<'PY'
import sys, pathlib
pathlib.Path(sys.argv[1] + ".bg_stripped").touch()
PY

SKIP_REMOVE_BG=1 bash "$SANDBOX7/tools/generate_asset.sh" sprite "test" >/dev/null 2>&1 || true
STRIPPED7="$(find "$SANDBOX7/assets/generated" -name "*.bg_stripped" | wc -l)"
[[ "$STRIPPED7" -eq 0 ]] \
  && pass "SKIP_REMOVE_BG suppresses background removal" \
  || fail "SKIP_REMOVE_BG did not suppress background removal"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "======================================="
echo "Results: $PASS passed, $FAIL failed"
echo "======================================="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for f in "${_FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

exit 0
