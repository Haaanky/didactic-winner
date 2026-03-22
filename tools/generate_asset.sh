#!/usr/bin/env bash
# generate_asset.sh — CLI batch asset generator for Dudes in Alaska
#
# API endpoints (keep in sync with addons/ai_assets/ai_asset_dock.gd):
#   Sprite : POST https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0
#   SFX    : POST https://api.elevenlabs.io/v1/sound-generation
#   Music  : POST https://router.huggingface.co/hf-inference/models/facebook/musicgen-small
#
# Usage (positional arguments):
#   ./tools/generate_asset.sh sprite "a pixel-art campfire in Alaska"
#   ./tools/generate_asset.sh sfx    "crackling campfire ambience"
#   ./tools/generate_asset.sh music  "peaceful acoustic guitar, Alaskan wilderness"
#
# Usage (JSON spec file):
#   ./tools/generate_asset.sh spec.json
#
#   spec.json format:
#   { "type": "sprite|sfx|music", "prompt": "description text" }
#
# Environment variables (or .env file in project root):
#   HUGGING_FACE         — required for sprite and music generation
#   ELEVENLABS_API_KEY   — required for SFX generation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/assets/generated"

SPRITE_API_URL="https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0"
SFX_API_URL="https://api.elevenlabs.io/v1/sound-generation"
MUSIC_API_URL="https://router.huggingface.co/hf-inference/models/facebook/musicgen-small"

# Load .env if it exists
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +a
fi

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//' | cut -c1-32
}

timestamp() {
  date +%s
}

build_filename() {
  local type_prefix="$1" prompt="$2" ext="$3"
  local slug
  slug="$(slugify "$prompt")"
  echo "${type_prefix}_${slug}_$(timestamp).${ext}"
}

die() {
  echo "ERROR: $1" >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"

# ---- Sprite (HuggingFace Stable Diffusion XL) ----

generate_sprite() {
  local prompt="$1"
  [[ -z "${HUGGING_FACE:-}" ]] && die "HUGGING_FACE not set"

  echo "Generating sprite: $prompt"
  local filename
  filename="$(build_filename sprite "$prompt" png)"

  curl -sS -X POST "$SPRITE_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $HUGGING_FACE" \
    -d "$(jq -n --arg p "$prompt" '{"inputs": $p}')" \
    -o "$OUTPUT_DIR/$filename"

  echo "Saved: $OUTPUT_DIR/$filename"
}

# ---- SFX (ElevenLabs) ----

generate_sfx() {
  local prompt="$1"
  [[ -z "${ELEVENLABS_API_KEY:-}" ]] && die "ELEVENLABS_API_KEY not set"

  echo "Generating SFX: $prompt"
  local filename
  filename="$(build_filename sfx "$prompt" mp3)"

  curl -sS -X POST "$SFX_API_URL" \
    -H "Content-Type: application/json" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -d "$(jq -n --arg t "$prompt" '{text: $t, duration_seconds: null, prompt_influence: 0.3}')" \
    -o "$OUTPUT_DIR/$filename"

  echo "Saved: $OUTPUT_DIR/$filename"
}

# ---- Music (HuggingFace MusicGen) ----

generate_music() {
  local prompt="$1"
  [[ -z "${HUGGING_FACE:-}" ]] && die "HUGGING_FACE not set"

  echo "Generating music (this may take up to a minute): $prompt"
  local filename
  filename="$(build_filename music "$prompt" flac)"

  curl -sS -X POST "$MUSIC_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $HUGGING_FACE" \
    -d "$(jq -n --arg p "$prompt" '{"inputs": $p}')" \
    --max-time 120 \
    -o "$OUTPUT_DIR/$filename"

  echo "Saved: $OUTPUT_DIR/$filename"
}

# ---- Main ----

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <sprite|sfx|music> \"prompt text\""
  echo "       $0 spec.json"
  exit 1
fi

# JSON spec file mode: single argument ending in .json
if [[ $# -eq 1 && "$1" == *.json ]]; then
  spec_file="$1"
  [[ ! -f "$spec_file" ]] && die "Spec file not found: $spec_file"

  asset_type="$(jq -r '.type // empty' "$spec_file")"
  asset_prompt="$(jq -r '.prompt // empty' "$spec_file")"
  [[ -z "$asset_type" ]] && die "Spec file missing \"type\" field"
  [[ -z "$asset_prompt" ]] && die "Spec file missing \"prompt\" field"

  case "$asset_type" in
    sprite) generate_sprite "$asset_prompt" ;;
    sfx)    generate_sfx "$asset_prompt" ;;
    music)  generate_music "$asset_prompt" ;;
    *)      die "Unknown asset type in spec: $asset_type (use sprite, sfx, or music)" ;;
  esac
  exit 0
fi

# Positional argument mode
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <sprite|sfx|music> \"prompt text\""
  echo "       $0 spec.json"
  exit 1
fi

case "$1" in
  sprite) generate_sprite "$2" ;;
  sfx)    generate_sfx "$2" ;;
  music)  generate_music "$2" ;;
  *)      die "Unknown asset type: $1 (use sprite, sfx, or music)" ;;
esac
