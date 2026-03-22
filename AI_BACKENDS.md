# cloud.md — AI Directive: Cloud & Local Backend Rules

This file extends `CLAUDE.md`. Read it at the start of every session.
All rules here carry the same weight as rules in `CLAUDE.md`.

---

## General principle — applies to every AI/LLM integration

> **Always try local first. Fall back to cloud automatically. Never ask the user to choose.**

This rule applies to **all** AI service calls in this project regardless of
provider or asset type — image generation, audio generation, text generation,
embeddings, or any other AI API. The backend selection must be invisible to the user.

---

## Mandatory rules for all AI service code

### 1. Never add manual backend selectors

Do **not** add dropdowns, buttons, flags, or settings that let the user choose
"Cloud" or "Local" manually. Backend selection must always be automatic.

### 2. Always probe before calling any AI service

Every code path that calls an AI API must:

1. Probe the local endpoint first (2 s timeout).
2. Use the local server if the probe succeeds.
3. Fall back to the cloud API if the probe fails.

```gdscript
# Correct — any AI call
if await _local_reachable(local_url):
    await _call_local_model(prompt)
else:
    await _call_cloud_api(prompt)

# Wrong — never hardcode cloud or skip the probe
await _call_cloud_api(prompt)
```

```bash
# Correct — shell equivalent
if probe_local "$local_url"; then
  call_local "$prompt"
else
  call_cloud "$prompt"
fi
```

### 3. Respect FORCE_CLOUD_AI

The probe must return false immediately when `FORCE_CLOUD_AI` is set to
any non-empty value. This is the only supported override mechanism.
Never check for any other override variable.

### 4. Probe timeout is 2 seconds

The probe must time out after exactly 2 000 ms. Do not raise or lower this
without updating every probe site in GDScript and shell simultaneously.

### 5. Keep endpoints in sync

When the project has both a GDScript implementation and a shell script for
the same AI integration, endpoint URLs must be defined in **both** and kept
identical. Change them together in the same commit.

### 6. Local URL overrides via environment variables

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

| Asset / service | Env var | Default |
|-----------------|---------|---------|
| Sprite | `LOCAL_SPRITE_URL` | `http://localhost:7860/sdapi/v1/txt2img` |
| SFX | `LOCAL_SFX_URL` | `http://localhost:8080/generate/sfx` |
| Music | `LOCAL_MUSIC_URL` | `http://localhost:8080/generate/music` |

Add a new row here whenever a new AI service is introduced.

### 7. Cloud API keys come from environment variables only

Never hardcode API keys. Read from OS environment. If a required key is
missing, call `push_error()` with the variable name and return early —
never silently skip the operation.

#### Current cloud API key env vars

| Env var | Service | Used for |
|---------|---------|----------|
| `OPENAI_API_KEY` | OpenAI | Sprites (DALL-E 3) |
| `ELEVENLABS_API_KEY` | ElevenLabs | SFX |
| `REPLICATE_API_TOKEN` | Replicate | Music (Suno) |

Add a new row here whenever a new cloud AI provider is introduced.

### 8. Adding a new AI service — checklist

When integrating any new AI or LLM service (text, image, audio, embeddings,
etc.), follow this checklist:

- [ ] Define a `LOCAL_<SERVICE>_URL` env var with a sensible localhost default
- [ ] Implement `probe_local` / `_local_reachable` call before every invocation
- [ ] Implement cloud fallback using an env-var API key
- [ ] Add the env var to the tables in sections 6 and 7 of this file
- [ ] Keep endpoint constants in sync across GDScript and shell
- [ ] Write GUT tests covering: missing API key, probe returns false (cloud used),
      probe returns true (local used)

### 9. Tests must cover probe and fallback paths

Every `push_error()` site in AI service code must have a GUT test that
exercises the error path, consistent with rule 13 in `CLAUDE.md`.

Update `tests/unit/test_ai_asset_dock.gd` (or the relevant test file)
whenever probe or fallback logic changes.
