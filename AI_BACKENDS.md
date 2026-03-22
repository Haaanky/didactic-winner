# cloud.md — AI Directive: Cloud & Local Backend Rules

This file extends `CLAUDE.md`. Read it at the start of every session.
All rules here carry the same weight as rules in `CLAUDE.md`.

---

## General principle — applies to every AI/LLM integration

> **Always try cloud first. If cloud fails, auto-start and use local. Never ask the user to choose.**

This rule applies to **all** AI service calls in this project regardless of
provider or asset type — image generation, audio generation, text generation,
embeddings, or any other AI API. The backend selection must be invisible to the user.

---

## CRITICAL: Never start local model servers inside a Claude Code session

The local servers (`tools/local_sprite_server.py`, `tools/local_audio_server.py`)
are **exclusively for the developer's own machine**. Do **not** start them, invoke
them, or trigger their installation inside a Claude Code (cloud) session.

**Why:** A Claude Code session runs in a cloud container. Starting a local model
server there would burn Anthropic compute for a 5–20 minute CPU job — not the
user's hardware. It is wasteful and will time out.

**Rule for AI assistants:** When running inside Claude Code:
- Do **not** execute `tools/local_sprite_server.py` or `tools/local_audio_server.py`
- Do **not** run `pip install torch`, `pip install diffusers`, or `pip install audiocraft`
- Do **not** call `./tools/generate_asset.sh` with `FORCE_LOCAL_AI=1`
- If cloud generation fails and there is no valid API key, report the missing key
  and instruct the user to run `generate_asset.sh` locally on their own machine

The local fallback path is only ever exercised by the developer running the script
on their own hardware.

---

## Mandatory rules for all AI service code

### 1. Never add manual backend selectors

Do **not** add dropdowns, buttons, flags, or settings that let the user choose
"Cloud" or "Local" manually. Backend selection must always be automatic.

### 2. Always try cloud first, then auto-start local on failure

Every code path that calls an AI API must:

1. Check if the cloud API key is available.
2. If key is present, attempt the cloud call.
3. If the cloud call succeeds, use the result.
4. If the cloud call fails (missing key, HTTP error, timeout), fall back to local:
   a. Probe the local endpoint (2 s timeout).
   b. If the local server is not reachable, run the configured start command.
   c. Wait up to 30 s for the local server to become reachable.
   d. Generate via the local server.
5. If both cloud and local fail, report the error clearly.

```gdscript
# Correct — any AI call
var ok := await _try_cloud(prompt)
if not ok:
    await _ensure_local_and_generate(prompt)

# Wrong — never skip cloud or hardcode local
await _generate_local(prompt)
```

```bash
# Correct — shell equivalent
if try_cloud "$prompt"; then
  : # done
else
  ensure_local_and_generate "$prompt"
fi
```

### 3. Respect FORCE_LOCAL_AI

When `FORCE_LOCAL_AI` is set to any non-empty value, skip cloud entirely and
go straight to local (spinning it up if needed). This is the only supported
override mechanism. Never check for any other override variable.

> Note: The old `FORCE_CLOUD_AI` variable is removed. Cloud is now the default.

### 4. Probe timeout is 2 seconds

The local probe must time out after exactly 2 000 ms. Do not raise or lower this
without updating every probe site in GDScript and shell simultaneously.

### 5. Local server spin-up timeout is 30 seconds

After launching the start command, poll the local endpoint every 500 ms.
If the server is not reachable within 30 s, report an error and stop.

### 6. Keep endpoints in sync

When the project has both a GDScript implementation and a shell script for
the same AI integration, endpoint URLs must be defined in **both** and kept
identical. Change them together in the same commit.

### 7. Local URL overrides via environment variables

Always check for an env-var override before using the hardcoded default.

Pattern (GDScript):
```gdscript
func _resolve_local_url(env_key: String, default_url: String) -> String:
    var override := _get_env(env_key)
    return override if not override.is_empty() else default_url
```

Pattern (shell):
```bash
local_url="${LOCAL_FOO_URL:-$LOCAL_FOO_DEFAULT_URL}"
```

#### Current local endpoint env vars

| Asset / service | URL env var | Default | Start-command env var |
|-----------------|-------------|---------|----------------------|
| Sprite | `LOCAL_SPRITE_URL` | `http://localhost:7860/sdapi/v1/txt2img` | `LOCAL_SPRITE_START_CMD` |
| SFX | `LOCAL_SFX_URL` | `http://localhost:8080/generate/sfx` | `LOCAL_SFX_START_CMD` |
| Music | `LOCAL_MUSIC_URL` | `http://localhost:8080/generate/music` | `LOCAL_MUSIC_START_CMD` |

Add a new row here whenever a new AI service is introduced.

**Start-command examples** (set in `.env`):
```bash
LOCAL_SPRITE_START_CMD="python /opt/sd-webui/launch.py --nowebui"
LOCAL_SFX_START_CMD="python /opt/audiocraft_server/server.py"
LOCAL_MUSIC_START_CMD="python /opt/audiocraft_server/server.py"
```

If a start command is not set, the fallback is skipped and an error is reported.

### 8. Cloud API keys come from environment variables only

Never hardcode API keys. Read from OS environment. If a required key is
missing, skip cloud silently (do not push_error — absence of a key is expected
in local-only setups) and proceed directly to local fallback.

#### Current cloud API key env vars

| Env var | Service | Used for | Priority |
|---------|---------|----------|----------|
| `OPENAI_API_KEY` | OpenAI | Sprites (DALL-E 3, PNG) | 1st |
| `HUGGING_FACE` | HuggingFace (FLUX.1-schnell) | Sprites (JPEG) | 2nd (fallback if OpenAI absent/fails) |
| `ELEVENLABS_API_KEY` | ElevenLabs | SFX (MP3) | 1st |
| `REPLICATE_API_TOKEN` | Replicate | Music / SFX (MP3) | 1st |

**Local audio format:** local AudioCraft servers return WAV; files are saved with `.wav` extension.
**Cloud audio format:** ElevenLabs and Replicate return MP3; files are saved with `.mp3` extension.

Add a new row here whenever a new cloud AI provider is introduced.

### 9. Adding a new AI service — checklist

When integrating any new AI or LLM service (text, image, audio, embeddings,
etc.), follow this checklist:

- [ ] Define a `LOCAL_<SERVICE>_URL` env var with a sensible localhost default
- [ ] Define a `LOCAL_<SERVICE>_START_CMD` env var for auto-starting the server
- [ ] Implement cloud call first; fall back to local on any failure
- [ ] Implement local probe + auto-spin-up on fallback path
- [ ] Add the env vars to the table in section 7 of this file
- [ ] Keep endpoint constants in sync across GDScript and shell
- [ ] Write GUT tests covering: missing API key (local used), cloud HTTP error
      (local used), probe true (local used without spin-up), probe false
      (spin-up attempted)

### 10. Tests must cover probe and fallback paths

Every `push_error()` site in AI service code must have a GUT test that
exercises the error path, consistent with rule 13 in `CLAUDE.md`.

Update `tests/unit/test_ai_asset_dock.gd` (or the relevant test file)
whenever probe, spin-up, or fallback logic changes.
