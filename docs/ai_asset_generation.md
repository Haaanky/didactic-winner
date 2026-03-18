# AI Asset Generation — Setup Guide

Generate sprites, sound effects, and music from text prompts using external AI APIs. Assets are created via the **Godot editor plugin** or the **CLI script** and automatically made available to the game through the `GeneratedAssetLoader` autoload.

---

## 1. Get API Keys

You need at least one key depending on which asset types you want to generate.

| Asset type | Service | Sign-up URL | Key name |
|---|---|---|---|
| **Sprites** (PNG) | OpenAI DALL-E 3 | https://platform.openai.com/signup | `OPENAI_API_KEY` |
| **Sound effects** (WAV) | ElevenLabs | https://elevenlabs.io/ | `ELEVENLABS_API_KEY` |
| **Music** (OGG) | Replicate (Suno) | https://replicate.com/ | `REPLICATE_API_TOKEN` |

### OpenAI (sprites)

1. Create an account at https://platform.openai.com/signup
2. Go to **API keys** → **Create new secret key**
3. Copy the key (starts with `sk-`)
4. Add billing / credits — DALL-E 3 charges per image (~$0.04 for 1024×1024)

### ElevenLabs (SFX)

1. Create an account at https://elevenlabs.io/
2. Go to **Profile** → **API Keys** → **Create API Key**
3. Copy the key
4. Free tier includes limited sound generation credits

### Replicate (music)

1. Create an account at https://replicate.com/
2. Go to **Account Settings** → **API tokens** → **Create token**
3. Copy the token
4. Add billing — Suno model charges per prediction (~$0.01–0.05 per track)

---

## 2. Configure the `.env` File

From the project root:

```bash
cp .env.example .env
```

Edit `.env` and paste your keys:

```
OPENAI_API_KEY=sk-proj-abc123...
ELEVENLABS_API_KEY=xi-abc123...
REPLICATE_API_TOKEN=r8_abc123...
```

**Important:**
- `.env` is gitignored — it will never be committed
- You only need keys for the asset types you plan to generate
- Both the CLI script and the editor plugin read keys from environment variables; the CLI script also sources `.env` automatically

---

## 3. Install Prerequisites (CLI only)

The CLI script (`tools/generate_asset.sh`) requires:

- **`curl`** — HTTP client (pre-installed on most systems)
- **`jq`** — JSON processor

```bash
# Ubuntu / Debian
sudo apt install curl jq

# macOS
brew install curl jq

# Arch
sudo pacman -S curl jq
```

The editor plugin has no external dependencies beyond Godot itself.

---

## 4. Generate Assets

### Option A: CLI Script

```bash
# Sprites
./tools/generate_asset.sh sprite "a pixel-art campfire in Alaska"

# Sound effects
./tools/generate_asset.sh sfx "crackling campfire ambience"

# Music
./tools/generate_asset.sh music "peaceful acoustic guitar, Alaskan wilderness"
```

All output is saved to `assets/generated/` with the naming pattern:
```
{type}_{slug}_{unix_timestamp}.{ext}
```

For example: `sprite_a_pixel_art_campfire_in_alaska_1710764400.png`

### Option B: Godot Editor Plugin

1. Open the project in Godot
2. Go to **Project → Project Settings → Plugins**
3. Enable **AI Asset Generator**
4. A dock panel appears in the editor (upper-right)
5. Select asset type, enter a prompt, click **Generate**
6. The file is saved to `assets/generated/` and appears in the FileSystem dock

**Note:** The editor plugin reads API keys from OS environment variables. Set them in your shell profile or launch Godot from a terminal where they are exported:

```bash
export OPENAI_API_KEY=sk-proj-abc123...
export ELEVENLABS_API_KEY=xi-abc123...
export REPLICATE_API_TOKEN=r8_abc123...
godot --path /path/to/didactic-winner
```

---

## 5. Use Generated Assets in the Game

Generated assets are automatically discovered by the `GeneratedAssetLoader` autoload at startup. It scans `assets/generated/` and categorises files by their prefix.

### Sprites

```gdscript
# Get a Texture2D by keyword match on the slug
var tex: Texture2D = GeneratedAssetLoader.get_sprite("campfire")

# Apply directly to a Sprite2D node
GeneratedAssetLoader.apply_sprite_to_node("campfire", $MySprite2D)
```

### Music

```gdscript
# Get all generated music track paths
var tracks: Array[String] = GeneratedAssetLoader.get_music_tracks()

# Play the first available generated track through AudioManager
GeneratedAssetLoader.play_generated_music()
```

### Sound Effects

```gdscript
# Get all generated SFX paths
var sfx_paths: Array[String] = GeneratedAssetLoader.get_sfx_paths()

# Load and play one through AudioManager
if not sfx_paths.is_empty():
    var stream: AudioStream = load(sfx_paths[0])
    AudioManager.play_sfx_global(stream)
```

### After Generating New Assets at Runtime

If you generate assets while the game is running (e.g. from the editor plugin), call:

```gdscript
GeneratedAssetLoader.rescan()
```

This re-scans the directory and picks up any new files.

---

## 6. File Layout

```
assets/generated/               ← all AI output lands here (gitignored)
├── sprite_campfire_1710764400.png
├── sfx_crackling_fire_1710764410.wav
└── music_peaceful_guitar_1710764420.ogg
```

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| `ERROR: OPENAI_API_KEY not set` | Add the key to `.env` or export it in your shell |
| `Error: HTTP 401` | Key is invalid or expired — regenerate it on the provider's dashboard |
| `Error: HTTP 429` | Rate limited — wait a minute and retry, or check your billing/quota |
| `Error: HTTP 400` | Prompt may be rejected by the content policy — rephrase it |
| Plugin not visible in editor | Enable it in Project → Project Settings → Plugins |
| Generated file not showing in Godot | Click the FileSystem dock refresh button, or call `EditorInterface.get_resource_filesystem().scan()` |
| CLI script permission denied | Run `chmod +x tools/generate_asset.sh` |
| `jq: command not found` | Install jq (see step 3) |
| Music generation times out | Replicate predictions can take 30–60s; the script polls for up to 60s by default |

---

## 8. Cost Estimates

| Asset | Provider | Approximate cost |
|---|---|---|
| 1 sprite (1024×1024) | OpenAI DALL-E 3 | ~$0.04 |
| 1 SFX clip (5 seconds) | ElevenLabs | Free tier or ~$0.01 |
| 1 music track (30 seconds) | Replicate / Suno | ~$0.01–0.05 |

All providers offer free tiers or trial credits for initial testing.
