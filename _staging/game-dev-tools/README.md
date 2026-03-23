# game-dev-tools

Generic AI asset generation tools for game and app development.

Generates sprites, SFX, and music via cloud APIs (OpenAI, ElevenLabs, Replicate) with automatic fallback to local servers (Stable Diffusion, AudioCraft).

## Quick start

```bash
cp config/.env.example .env   # fill in API keys
./src/generate_asset.sh sprite "pixel-art campfire"
./src/generate_asset.sh sfx    "crackling campfire ambience"
./src/generate_asset.sh music  "peaceful acoustic guitar"
```

Assets are saved to `assets/generated/` in the **current working directory** by default.
Override with the `ASSET_OUTPUT_DIR` env var:

```bash
ASSET_OUTPUT_DIR=/path/to/project/assets/generated ./src/generate_asset.sh sprite "..."
```

## Directory structure

```
game-dev-tools/
├── src/
│   ├── generate_asset.sh          # CLI entry point
│   └── servers/
│       ├── local_sprite_server.py # AUTOMATIC1111-compatible sprite server (CPU)
│       └── local_audio_server.py  # AudioCraft-based SFX/music server (CPU)
├── tests/                         # pytest unit tests
├── docs/
│   └── AI_BACKENDS.md             # Backend selection rules
├── config/
│   └── .env.example               # Environment variable template
├── .gitignore
└── README.md
```

## Environment variables

| Variable | Service | Purpose |
|---|---|---|
| `OPENAI_API_KEY` | OpenAI | Sprite generation (DALL-E 3) |
| `HUGGING_FACE` | HuggingFace | Sprite generation (FLUX.1-schnell, fallback) |
| `ELEVENLABS_API_KEY` | ElevenLabs | SFX generation |
| `REPLICATE_API_TOKEN` | Replicate | Music generation |
| `LOCAL_SPRITE_URL` | — | Override local sprite endpoint |
| `LOCAL_SFX_URL` | — | Override local SFX endpoint |
| `LOCAL_MUSIC_URL` | — | Override local music endpoint |
| `LOCAL_SPRITE_START_CMD` | — | Command to auto-start sprite server |
| `LOCAL_SFX_START_CMD` | — | Command to auto-start SFX server |
| `LOCAL_MUSIC_START_CMD` | — | Command to auto-start music server |
| `FORCE_LOCAL_AI` | — | Skip cloud, always use local |
| `ASSET_OUTPUT_DIR` | — | Output directory (default: `$PWD/assets/generated`) |

## Local servers

The local servers require GPU for reasonable speed but run on CPU (slowly) if no GPU is available.

```bash
# Sprite server (AUTOMATIC1111-compatible, port 7860)
python src/servers/local_sprite_server.py

# Audio server (AudioCraft/MusicGen, port 8080)
python src/servers/local_audio_server.py
```

> **Note:** Never start local servers from a shared cloud CI environment. Cloud APIs are the intended path for CI; local servers are for development machines only.

## Using in another project

From a Godot or other project root:

```bash
ASSET_OUTPUT_DIR=./assets/generated /path/to/game-dev-tools/src/generate_asset.sh sprite "..."
```

Or install globally:

```bash
ln -s /path/to/game-dev-tools/src/generate_asset.sh /usr/local/bin/generate_asset
generate_asset sprite "pixel-art sword"
```

## SessionStart hook integration

Add to `.claude/settings.json` in your project:

```json
{
  "hooks": {
    "SessionStart": [{
      "type": "command",
      "command": "bash -c 'if [ ! -f /usr/local/bin/generate_asset ]; then ln -s $(pwd)/../game-dev-tools/src/generate_asset.sh /usr/local/bin/generate_asset; fi'"
    }]
  }
}
```
