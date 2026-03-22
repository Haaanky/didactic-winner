# AI Asset Generation — Cloud & Local Backends

The asset generator (editor dock + CLI) selects backend automatically each time you generate an asset. No manual toggle is needed.

---

## How it works

1. Before each generation the tool probes the relevant local endpoint (2 s timeout).
2. If the local server responds → **local generation** is used.
3. If the local server is down or unreachable → **cloud API** is used.

The probe happens per asset type, so your sprite server and music server can be independent.

---

## Backends

| Asset | Local server | Cloud API |
|-------|-------------|-----------|
| Sprite (PNG) | AUTOMATIC1111 WebUI | OpenAI DALL-E 3 |
| SFX (MP3) | AudioCraft wrapper | ElevenLabs |
| Music (MP3) | MusicGen wrapper | Suno via Replicate |

---

## Environment variables

Copy `.env.example` to `.env` in the project root and fill in the values you need.

### API keys (cloud)

| Variable | Service |
|----------|---------|
| `OPENAI_API_KEY` | OpenAI DALL-E 3 (sprites) |
| `ELEVENLABS_API_KEY` | ElevenLabs (SFX) |
| `REPLICATE_API_TOKEN` | Replicate / Suno (music) |

### Local endpoint overrides

The defaults point to standard localhost ports. Override if you run servers elsewhere.

| Variable | Default |
|----------|---------|
| `LOCAL_SPRITE_URL` | `http://localhost:7860/sdapi/v1/txt2img` |
| `LOCAL_SFX_URL` | `http://localhost:8080/generate/sfx` |
| `LOCAL_MUSIC_URL` | `http://localhost:8080/generate/music` |

### Behaviour flags

| Variable | Effect |
|----------|--------|
| `FORCE_CLOUD_AI` | Set to any non-empty value to skip probing and always use cloud APIs |

---

## Starting local servers

### Sprite — AUTOMATIC1111

```bash
# Clone and start the WebUI (first run downloads models)
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui
cd stable-diffusion-webui
./webui.sh --api --nowebui
# Listens on http://localhost:7860
```

### SFX & Music — AudioCraft wrapper

A minimal FastAPI wrapper for Meta AudioCraft is needed. A community example:

```bash
pip install audiocraft fastapi uvicorn
uvicorn audiocraft_server:app --port 8080
# Expected routes:
#   POST /generate/sfx   { "text": "...", "duration": 5 }
#   POST /generate/music { "text": "...", "duration": 30 }
# Both return raw MP3 bytes.
```

---

## CLI usage

```bash
# Auto-detect backend, generate each asset type
./tools/generate_asset.sh sprite "pixel-art campfire in Alaska"
./tools/generate_asset.sh sfx    "crackling campfire ambience"
./tools/generate_asset.sh music  "peaceful acoustic guitar, Alaskan wilderness"

# Force cloud regardless of local servers
FORCE_CLOUD_AI=1 ./tools/generate_asset.sh sprite "snowy pine forest"

# Use a JSON spec file
./tools/generate_asset.sh spec.json
```

`spec.json` format:
```json
{ "type": "sprite", "prompt": "pixel-art campfire in Alaska" }
```

---

## Generated files

All assets are saved to `assets/generated/` with the pattern:

```
{type}_{slug}_{unix_timestamp}.{ext}
```

Example: `sprite_pixel_art_campfire_in_alaska_1711234567.png`

This directory is gitignored.
