# Dudes in Alaska

A 2D game built with [Godot 4](https://godotengine.org/).

## Getting Started

1. Download [Godot 4](https://godotengine.org/download) (Standard, no Mono)
2. Open Godot and import `project.godot` from this repository
3. Press **F5** to run

https://haaanky.github.io/didactic-winner/

See [CLAUDE.md](./CLAUDE.md) for full project conventions, structure, and development guidelines.

See [docs/CONTROLS.md](./docs/CONTROLS.md) for the full list of keyboard and gamepad bindings.

## Asset Generation Setup

The project includes an **AI Asset Generator** plugin and CLI tool for creating sprites, SFX, and music from text prompts.

### API Keys

Copy `.env.example` to `.env` and fill in any keys you need:

| Variable | Service | Used for |
|----------|---------|----------|
| `OPENAI_API_KEY` | OpenAI (DALL-E 3) | Sprite generation |
| `ELEVENLABS_API_KEY` | ElevenLabs | SFX generation |
| `REPLICATE_API_TOKEN` | Replicate (Suno) | Music generation |

### Editor Plugin

1. Open the project in Godot 4
2. Go to **Project > Project Settings > Plugins**
3. Enable **AI Asset Generator**
4. A dock panel appears in the editor — pick an asset type, enter a prompt, and click **Generate**

Generated files are saved to `assets/generated/` (gitignored).

### CLI Tool

```bash
./tools/generate_asset.sh sprite "a pixel-art campfire in Alaska"
./tools/generate_asset.sh sfx    "crackling campfire ambience"
./tools/generate_asset.sh music  "peaceful acoustic guitar, Alaskan wilderness"
```

Requires `curl` and `jq`. Reads keys from environment variables or `.env`.

## License

This project is licensed under the [GNU General Public License v3.0](./LICENSE).

