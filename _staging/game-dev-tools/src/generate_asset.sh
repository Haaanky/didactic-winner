#!/usr/bin/env bash
# generate_asset.sh — CLI AI asset generator for game and app development
#
# Cloud API endpoints:
#   Sprite : POST https://api.openai.com/v1/images/generations           (OPENAI_API_KEY)
#          : POST https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell  (HUGGING_FACE)
#   SFX    : POST https://api.elevenlabs.io/v1/sound-generation
#   Music  : POST https://api.replicate.com/v1/predictions
#            GET  https://api.replicate.com/v1/predictions/{id}
#
# Local endpoints:
#   Sprite : POST http://localhost:7860/sdapi/v1/txt2img  (AUTOMATIC1111)
#            Override with LOCAL_SPRITE_URL env var.
#            Auto-start with LOCAL_SPRITE_START_CMD env var.
#   SFX    : POST http://localhost:8080/generate/sfx  (AudioCraft wrapper)
#            Override with LOCAL_SFX_URL env var.
#            Auto-start with LOCAL_SFX_START_CMD env var.
#   Music  : POST http://localhost:8080/generate/music  (MusicGen wrapper)
#            Override with LOCAL_MUSIC_URL env var.
#            Auto-start with LOCAL_MUSIC_START_CMD env var.
#
# Backend selection is automatic:
#   Cloud is tried first. If cloud is unavailable (missing key or HTTP error),
#   the script probes the local server and starts it automatically if needed.
#   Set FORCE_LOCAL_AI=1 to skip cloud and always use the local server.
#
# Usage:
#   ./src/generate_asset.sh sprite "a pixel-art campfire"
#   ./src/generate_asset.sh sfx    "crackling campfire ambience"
#   ./src/generate_asset.sh music  "peaceful acoustic guitar"
#
# Usage (JSON spec file):
#   ./src/generate_asset.sh spec.json
#
#   spec.json format:
#   { "type": "sprite|sfx|music", "prompt": "description text" }
#
# Environment variables (or .env file in the directory this script is called from):
#   OPENAI_API_KEY           — cloud sprite generation (DALL-E 3); tried first
#   HUGGING_FACE             — cloud sprite generation (FLUX.1-schnell); tried if OPENAI fails
#   ELEVENLABS_API_KEY       — required for cloud SFX generation
#   REPLICATE_API_TOKEN      — required for cloud music generation
#   LOCAL_SPRITE_URL         — override local sprite endpoint (optional)
#   LOCAL_SFX_URL            — override local SFX endpoint (optional)
#   LOCAL_MUSIC_URL          — override local music endpoint (optional)
#   LOCAL_SPRITE_START_CMD   — command to auto-start the local sprite server
#   LOCAL_SFX_START_CMD      — command to auto-start the local SFX server
#   LOCAL_MUSIC_START_CMD    — command to auto-start the local music server
#   FORCE_LOCAL_AI           — set to any value to skip cloud and use local
#   ASSET_OUTPUT_DIR         — output directory (default: $PWD/assets/generated)

set -euo pipefail

# Output directory: env var override, else current working directory / assets/generated
OUTPUT_DIR="${ASSET_OUTPUT_DIR:-$PWD/assets/generated}"

SPRITE_API_URL="https://api.openai.com/v1/images/generations"
HF_SPRITE_API_URL="https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"
SFX_API_URL="https://api.elevenlabs.io/v1/sound-generation"
MUSIC_API_URL="https://api.replicate.com/v1/predictions"

LOCAL_SPRITE_DEFAULT_URL="http://localhost:7860/sdapi/v1/txt2img"
LOCAL_SFX_DEFAULT_URL="http://localhost:8080/generate/sfx"
LOCAL_MUSIC_DEFAULT_URL="http://localhost:8080/generate/music"

LOCAL_SPRITE_RESOLUTION=256
LOCAL_SPRITE_STEPS=20
LOCAL_SPRITE_CFG_SCALE=7.0

MUSIC_POLL_INTERVAL=3
MUSIC_POLL_MAX_ATTEMPTS=20

SPIN_UP_TIMEOUT=30
SPIN_UP_POLL=0.5

# Load .env from current working directory if it exists
if [[ -f "$PWD/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$PWD/.env"
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

probe_local() {
  local url="$1"
  curl --connect-timeout 2 -s -o /dev/null "$url" 2>/dev/null
}

spin_up_server() {
  local start_cmd_var="$1" probe_url="$2"
  local start_cmd="${!start_cmd_var:-}"
  if [[ -z "$start_cmd" ]]; then
    echo "WARNING: $start_cmd_var not set — cannot auto-start local server" >&2
    return 1
  fi
  echo "Starting local server: $start_cmd"
  eval "$start_cmd" &
  local elapsed=0
  while (( $(echo "$elapsed < $SPIN_UP_TIMEOUT" | bc -l) )); do
    sleep "$SPIN_UP_POLL"
    elapsed=$(echo "$elapsed + $SPIN_UP_POLL" | bc -l)
    if probe_local "$probe_url"; then
      echo "Local server ready."
      return 0
    fi
  done
  echo "ERROR: local server did not start within ${SPIN_UP_TIMEOUT}s — $probe_url" >&2
  return 1
}

ensure_local_server() {
  local url="$1" start_cmd_var="$2"
  if probe_local "$url"; then
    return 0
  fi
  spin_up_server "$start_cmd_var" "$url"
}

mkdir -p "$OUTPUT_DIR"

# ---- Sprite ----

generate_sprite() {
  local prompt="$1"
  local local_url="${LOCAL_SPRITE_URL:-$LOCAL_SPRITE_DEFAULT_URL}"

  if [[ -z "${FORCE_LOCAL_AI:-}" ]]; then
    _try_generate_sprite_cloud "$prompt" && return 0
    _try_generate_sprite_hf "$prompt" && return 0
  fi

  echo "Falling back to local sprite server..."
  ensure_local_server "$local_url" "LOCAL_SPRITE_START_CMD"
  _generate_sprite_local "$prompt" "$local_url"
}

_try_generate_sprite_cloud() {
  local prompt="$1"
  [[ -z "${OPENAI_API_KEY:-}" ]] && return 1

  echo "Generating sprite (cloud — OpenAI DALL-E): $prompt"
  local response http_code
  response="$(curl -sS -w "\n%{http_code}" -X POST "$SPRITE_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$(jq -n --arg p "$prompt" '{
      model: "dall-e-3",
      prompt: $p,
      n: 1,
      size: "1024x1024",
      response_format: "url"
    }')")"
  http_code="$(echo "$response" | tail -n1)"
  response="$(echo "$response" | head -n -1)"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "Cloud sprite failed (HTTP $http_code) — will try local." >&2
    return 1
  fi

  local image_url
  image_url="$(echo "$response" | jq -r '.data[0].url // empty')"
  if [[ -z "$image_url" ]]; then
    echo "Cloud sprite failed (no image URL) — will try local." >&2
    return 1
  fi

  local filename tmp_file dl_code
  filename="$(build_filename sprite "$prompt" png)"
  tmp_file="$(mktemp)"
  dl_code="$(curl -sS -o "$tmp_file" -w "%{http_code}" "$image_url")"

  if [[ "$dl_code" -lt 200 || "$dl_code" -ge 300 ]]; then
    rm -f "$tmp_file"
    echo "Cloud sprite download failed (HTTP $dl_code) — will try local." >&2
    return 1
  fi

  mv "$tmp_file" "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
  return 0
}

_try_generate_sprite_hf() {
  local prompt="$1"
  [[ -z "${HUGGING_FACE:-}" ]] && return 1

  echo "Generating sprite (cloud — HuggingFace FLUX.1-schnell): $prompt"
  local tmp_file http_code
  tmp_file="$(mktemp)"
  http_code="$(curl -sS -X POST "$HF_SPRITE_API_URL" \
    -H "Authorization: Bearer $HUGGING_FACE" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg p "$prompt" '{inputs: $p}')" \
    -o "$tmp_file" \
    -w "%{http_code}")"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    local err; err="$(head -c 200 "$tmp_file")"; rm -f "$tmp_file"
    echo "Cloud sprite (HF) failed (HTTP $http_code: $err) — will try local." >&2
    return 1
  fi

  local filename
  filename="$(build_filename sprite "$prompt" jpg)"
  mv "$tmp_file" "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
  return 0
}

_generate_sprite_local() {
  local prompt="$1" url="$2"

  echo "Generating sprite (local — $url): $prompt"
  local response
  response="$(curl -sS -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg p "$prompt" \
      --argjson w "$LOCAL_SPRITE_RESOLUTION" \
      --argjson h "$LOCAL_SPRITE_RESOLUTION" \
      --argjson steps "$LOCAL_SPRITE_STEPS" \
      --argjson cfg "$LOCAL_SPRITE_CFG_SCALE" \
      '{prompt: $p, width: $w, height: $h, steps: $steps, cfg_scale: $cfg}')")"

  local b64
  b64="$(echo "$response" | jq -r '.images[0] // empty')"
  [[ -z "$b64" ]] && die "No images in local API response: $(echo "$response" | head -c 200)"

  local filename
  filename="$(build_filename sprite "$prompt" png)"
  echo "$b64" | base64 -d > "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
}

# ---- SFX ----

generate_sfx() {
  local prompt="$1"
  local local_url="${LOCAL_SFX_URL:-$LOCAL_SFX_DEFAULT_URL}"

  if [[ -z "${FORCE_LOCAL_AI:-}" ]] && _try_generate_sfx_cloud "$prompt"; then
    return 0
  fi

  echo "Falling back to local SFX server..."
  ensure_local_server "$local_url" "LOCAL_SFX_START_CMD"
  _generate_sfx_local "$prompt" "$local_url"
}

_try_generate_sfx_cloud() {
  local prompt="$1"
  [[ -z "${ELEVENLABS_API_KEY:-}" ]] && return 1

  echo "Generating SFX (cloud — ElevenLabs): $prompt"
  local tmp_file http_code
  tmp_file="$(mktemp)"
  http_code="$(curl -sS -X POST "$SFX_API_URL" \
    -H "Content-Type: application/json" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -d "$(jq -n --arg t "$prompt" '{text: $t, duration_seconds: null, prompt_influence: 0.3}')" \
    -o "$tmp_file" \
    -w "%{http_code}")"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    local err; err="$(cat "$tmp_file")"; rm -f "$tmp_file"
    echo "Cloud SFX failed (HTTP $http_code: $err) — will try local." >&2
    return 1
  fi

  local filename
  filename="$(build_filename sfx "$prompt" mp3)"
  mv "$tmp_file" "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
  return 0
}

_generate_sfx_local() {
  local prompt="$1" url="$2"

  echo "Generating SFX (local — $url): $prompt"
  local tmp_file http_code
  tmp_file="$(mktemp)"
  http_code="$(curl -sS -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg t "$prompt" '{text: $t, duration: 5}')" \
    -o "$tmp_file" \
    -w "%{http_code}")"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    local err; err="$(cat "$tmp_file")"; rm -f "$tmp_file"
    die "Local SFX server returned HTTP $http_code — $err"
  fi

  local filename
  filename="$(build_filename sfx "$prompt" wav)"
  mv "$tmp_file" "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
}

# ---- Music ----

generate_music() {
  local prompt="$1"
  local local_url="${LOCAL_MUSIC_URL:-$LOCAL_MUSIC_DEFAULT_URL}"

  if [[ -z "${FORCE_LOCAL_AI:-}" ]] && _try_generate_music_cloud "$prompt"; then
    return 0
  fi

  echo "Falling back to local music server..."
  ensure_local_server "$local_url" "LOCAL_MUSIC_START_CMD"
  _generate_music_local "$prompt" "$local_url"
}

_try_generate_music_cloud() {
  local prompt="$1"
  [[ -z "${REPLICATE_API_TOKEN:-}" ]] && return 1

  echo "Generating music (cloud — Replicate): $prompt"
  local response http_code
  response="$(curl -sS -w "\n%{http_code}" -X POST "$MUSIC_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
    -d "$(jq -n --arg p "$prompt" '{
      version: "7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
      input: {prompt: $p, model_version: "chirp-v3-5", duration: 30}
    }')")"
  http_code="$(echo "$response" | tail -n1)"
  response="$(echo "$response" | head -n -1)"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "Cloud music failed (HTTP $http_code) — will try local." >&2
    return 1
  fi

  local poll_url
  poll_url="$(echo "$response" | jq -r '.urls.get // empty')"
  if [[ -z "$poll_url" ]]; then
    echo "Cloud music failed (no poll URL) — will try local." >&2
    return 1
  fi

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
      echo "Cloud music prediction $status — will try local." >&2
      return 1
    fi
  done

  if [[ -z "$audio_url" ]]; then
    echo "Cloud music timed out — will try local." >&2
    return 1
  fi

  local filename tmp_file dl_code
  filename="$(build_filename music "$prompt" mp3)"
  tmp_file="$(mktemp)"
  dl_code="$(curl -sS -o "$tmp_file" -w "%{http_code}" "$audio_url")"

  if [[ "$dl_code" -lt 200 || "$dl_code" -ge 300 ]]; then
    rm -f "$tmp_file"
    echo "Cloud music download failed (HTTP $dl_code) — will try local." >&2
    return 1
  fi

  mv "$tmp_file" "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
  return 0
}

_generate_music_local() {
  local prompt="$1" url="$2"

  echo "Generating music (local — $url): $prompt"
  local tmp_file http_code
  tmp_file="$(mktemp)"
  http_code="$(curl -sS -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg t "$prompt" '{text: $t, duration: 30}')" \
    -o "$tmp_file" \
    -w "%{http_code}")"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    local err; err="$(cat "$tmp_file")"; rm -f "$tmp_file"
    die "Local music server returned HTTP $http_code — $err"
  fi

  local filename
  filename="$(build_filename music "$prompt" wav)"
  mv "$tmp_file" "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
}

# ---- Main ----

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <sprite|sfx|music> \"prompt text\""
  echo "       $0 spec.json"
  exit 1
fi

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
