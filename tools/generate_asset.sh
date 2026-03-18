#!/usr/bin/env bash
# generate_asset.sh — CLI batch asset generator for Dudes in Alaska
#
# API endpoints (keep in sync with addons/ai_assets/ai_asset_dock.gd):
#   Sprite : POST https://api.openai.com/v1/images/generations
#   SFX    : POST https://api.elevenlabs.io/v1/sound-generation
#   Music  : POST https://api.replicate.com/v1/predictions
#            GET  https://api.replicate.com/v1/predictions/{id}
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
#   OPENAI_API_KEY       — required for sprite generation
#   ELEVENLABS_API_KEY   — required for SFX generation
#   REPLICATE_API_TOKEN  — required for music generation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/assets/generated"

SPRITE_API_URL="https://api.openai.com/v1/images/generations"
SFX_API_URL="https://api.elevenlabs.io/v1/sound-generation"
MUSIC_API_URL="https://api.replicate.com/v1/predictions"

MUSIC_POLL_INTERVAL=3
MUSIC_POLL_MAX_ATTEMPTS=20

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

# ---- Sprite (OpenAI DALL-E) ----

generate_sprite() {
  local prompt="$1"
  [[ -z "${OPENAI_API_KEY:-}" ]] && die "OPENAI_API_KEY not set"

  echo "Generating sprite: $prompt"
  local response
  response="$(curl -sS -X POST "$SPRITE_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$(jq -n --arg p "$prompt" '{
      model: "dall-e-3",
      prompt: $p,
      n: 1,
      size: "256x256",
      response_format: "url"
    }')")"

  local image_url
  image_url="$(echo "$response" | jq -r '.data[0].url // empty')"
  [[ -z "$image_url" ]] && die "No image URL in response: $(echo "$response" | head -c 200)"

  local filename
  filename="$(build_filename sprite "$prompt" png)"
  curl -sS -o "$OUTPUT_DIR/$filename" "$image_url"
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

# ---- Music (Suno via Replicate) ----

generate_music() {
  local prompt="$1"
  [[ -z "${REPLICATE_API_TOKEN:-}" ]] && die "REPLICATE_API_TOKEN not set"

  echo "Generating music: $prompt"
  local response
  response="$(curl -sS -X POST "$MUSIC_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
    -d "$(jq -n --arg p "$prompt" '{
      version: "7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
      input: {prompt: $p, model_version: "chirp-v3-5", duration: 30}
    }')")"

  local poll_url
  poll_url="$(echo "$response" | jq -r '.urls.get // empty')"
  [[ -z "$poll_url" ]] && die "No poll URL in response: $(echo "$response" | head -c 200)"

  echo "Polling for music result..."
  local audio_url=""
  for i in $(seq 1 $MUSIC_POLL_MAX_ATTEMPTS); do
    sleep $MUSIC_POLL_INTERVAL
    local poll_result
    poll_result="$(curl -sS "$poll_url" \
      -H "Authorization: Bearer $REPLICATE_API_TOKEN")"

    local status
    status="$(echo "$poll_result" | jq -r '.status // empty')"

    echo "  Poll $i/$MUSIC_POLL_MAX_ATTEMPTS — status: $status"

    if [[ "$status" == "succeeded" ]]; then
      audio_url="$(echo "$poll_result" | jq -r 'if .output | type == "string" then .output elif .output | type == "array" then .output[0] else empty end')"
      break
    elif [[ "$status" == "failed" || "$status" == "canceled" ]]; then
      die "Replicate prediction $status"
    fi
  done

  [[ -z "$audio_url" ]] && die "Music generation timed out"

  local filename
  filename="$(build_filename music "$prompt" mp3)"
  curl -sS -o "$OUTPUT_DIR/$filename" "$audio_url"
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
