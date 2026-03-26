#!/usr/bin/env bash
# tools/generate_asset.sh — project wrapper for AI asset generation
#
# Fallback chain (tried in order):
#   1. vendor/game-dev-tools/src/generate_asset.sh  (git submodule — primary)
#   2. tools/_generate_asset_internal.sh             (project-internal copy — secondary)
#   3. Agent built-in skills                         (documented in docs/asset_generation_architecture.md)
#
# After any successful sprite generation, tools/remove_bg.py is run on the
# saved file to strip the white background (the submodule does not do this).
#
# Usage (identical to generate_asset.sh in game-dev-tools):
#   ./tools/generate_asset.sh sprite "pixel-art campfire in Alaska"
#   ./tools/generate_asset.sh sfx    "crackling campfire ambience"
#   ./tools/generate_asset.sh music  "peaceful acoustic guitar, Alaskan wilderness"
#   ./tools/generate_asset.sh spec.json
#
# Environment variables:
#   All variables accepted by the underlying generators are passed through.
#   ASSET_OUTPUT_DIR is set automatically to assets/generated/ — do not override
#   unless you know what you are doing.
#   SKIP_REMOVE_BG=1  — skip background removal (testing / debugging only)
#   FORCE_INTERNAL=1  — skip submodule, use internal fallback directly
#
# Submodule initialisation:
#   git submodule update --init vendor/game-dev-tools
#
# See also:
#   docs/asset_generation_architecture.md  — full fallback chain + agent instructions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUBMODULE_SCRIPT="$PROJECT_ROOT/vendor/game-dev-tools/src/generate_asset.sh"
INTERNAL_SCRIPT="$PROJECT_ROOT/tools/_generate_asset_internal.sh"
REMOVE_BG_SCRIPT="$PROJECT_ROOT/tools/remove_bg.py"
OUTPUT_DIR="$PROJECT_ROOT/assets/generated"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_die() {
  echo "ERROR: $1" >&2
  exit 1
}

# Detect asset type from CLI args or spec file.
# Prints "sprite", "sfx", "music", or "" if unknown.
_detect_asset_type() {
  local first="${1:-}"
  if [[ "$first" == "sprite" || "$first" == "sfx" || "$first" == "music" ]]; then
    echo "$first"
  elif [[ "$first" == *.json && -f "$first" ]]; then
    jq -r '.type // empty' "$first" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Run remove_bg.py on a file if it looks like a sprite image.
_strip_bg_if_sprite() {
  local file="$1"
  [[ "${SKIP_REMOVE_BG:-}" == "1" ]] && return 0
  if [[ ! -f "$REMOVE_BG_SCRIPT" ]]; then
    echo "WARNING: tools/remove_bg.py not found — background not stripped from $file" >&2
    return 0
  fi
  local ext="${file##*.}"
  if [[ "$ext" == "png" || "$ext" == "jpg" || "$ext" == "jpeg" ]]; then
    python3 "$REMOVE_BG_SCRIPT" "$file" 2>/dev/null \
      || echo "WARNING: background removal failed for $file — leaving as-is" >&2
  fi
}

# Run a generator script, stream output to stdout, capture the "Saved: " path.
# Prints the saved path on success. Returns non-zero on failure.
_run_generator() {
  local script="$1"
  shift
  local asset_type
  asset_type="$(_detect_asset_type "${1:-}")"

  local tmpout
  tmpout="$(mktemp)"
  # Stream to terminal and capture simultaneously
  if ASSET_OUTPUT_DIR="$OUTPUT_DIR" "$script" "$@" 2>&1 | tee "$tmpout"; then
    local saved_path
    saved_path="$(grep -m1 "^Saved: " "$tmpout" | sed 's/^Saved: //' || true)"
    rm -f "$tmpout"
    if [[ -n "$saved_path" && "$asset_type" == "sprite" ]]; then
      _strip_bg_if_sprite "$saved_path"
    fi
    return 0
  else
    local exit_code=${PIPESTATUS[0]}
    rm -f "$tmpout"
    return "$exit_code"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <sprite|sfx|music> \"prompt text\""
  echo "       $0 spec.json"
  echo ""
  echo "Asset generator wrapper. See docs/asset_generation_architecture.md"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ---- Tier 1: submodule ----
if [[ -z "${FORCE_INTERNAL:-}" ]] && [[ -x "$SUBMODULE_SCRIPT" ]]; then
  if _run_generator "$SUBMODULE_SCRIPT" "$@"; then
    exit 0
  fi
  echo "WARNING: submodule generator failed — trying internal fallback..." >&2
else
  if [[ -z "${FORCE_INTERNAL:-}" ]]; then
    echo "INFO: submodule not initialised ($SUBMODULE_SCRIPT not found)." >&2
    echo "INFO: Run: git submodule update --init vendor/game-dev-tools" >&2
    echo "INFO: Falling back to internal script..." >&2
  fi
fi

# ---- Tier 2: internal project copy ----
if [[ -x "$INTERNAL_SCRIPT" ]]; then
  if _run_generator "$INTERNAL_SCRIPT" "$@"; then
    exit 0
  fi
  echo "WARNING: internal generator also failed." >&2
else
  echo "INFO: internal fallback not found at $INTERNAL_SCRIPT" >&2
fi

# ---- Tier 3: agent built-in skills (documented path — not a code path) ----
cat >&2 <<'EOF'

All automated asset generators failed. If you are an AI agent:
  See docs/asset_generation_architecture.md §4 "Agent Built-in Skills Fallback"
  for instructions on generating placeholder assets using built-in capabilities.

If you are a human developer, resolve one of the following:
  A) Init the submodule:   git submodule update --init vendor/game-dev-tools
  B) Set an API key in .env (OPENAI_API_KEY, ELEVENLABS_API_KEY, or REPLICATE_API_TOKEN)
  C) Start a local server and set LOCAL_*_START_CMD in .env
EOF
exit 1
