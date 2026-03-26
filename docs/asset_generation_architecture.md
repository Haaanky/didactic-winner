# Asset Generation Architecture — Dudes in Alaska

## Purpose

This document is the authoritative reference for **AI agents and human developers**
on how asset generation works in this project, which tools are involved, and how
the four-tier fallback chain operates. Read this alongside `ASSET_POLICY.md` and
`AI_BACKENDS.md`.

---

## Overview

All asset generation is routed through a single entry point:

```
tools/generate_asset.sh <sprite|sfx|music> "prompt"
```

This wrapper tries four tiers in order and stops at the first success.

```
┌──────────────────────────────────────────────────────────────┐
│                tools/generate_asset.sh                       │
│                     (wrapper)                                │
└──────────────────────────┬───────────────────────────────────┘
                           │
          ┌────────────────▼──────────────────┐
          │  Tier 1 — Submodule               │ vendor/game-dev-tools/src/generate_asset.sh
          │  (primary, cloud-first)           │ Cloud APIs → local servers
          └────────────────┬──────────────────┘
                    FAIL ▼
          ┌────────────────▼──────────────────┐
          │  Tier 2 — Internal copy           │ tools/_generate_asset_internal.sh
          │  (project-local backup)           │ Cloud APIs → local servers
          └────────────────┬──────────────────┘
                    FAIL ▼
          ┌────────────────▼──────────────────┐
          │  Tier 3 — Local AI servers        │ See AI_BACKENDS.md §2
          │  (already embedded in tiers 1+2)  │ AUTOMATIC1111, AudioCraft
          └────────────────┬──────────────────┘
                    FAIL ▼
          ┌────────────────▼──────────────────┐
          │  Tier 4 — Agent Built-in Skills   │ Claude can generate placeholder assets
          │  (last resort, AI agents only)    │ directly — see §4 below
          └───────────────────────────────────┘
```

After any successful **sprite** generation (tiers 1 or 2), the wrapper
automatically runs `tools/remove_bg.py` to strip the white background.

---

## §1 — Tier 1: Submodule (`vendor/game-dev-tools`)

**Path:** `vendor/game-dev-tools/src/generate_asset.sh`
**Source:** https://github.com/Haaanky/game-dev-tools

The submodule is the canonical, maintained version of the generator. It is
generic (not Dudes-in-Alaska-specific) and receives upstream fixes and
improvements. The wrapper sets `ASSET_OUTPUT_DIR` to `assets/generated/`
before calling it.

### Initialising the submodule

```bash
git submodule update --init vendor/game-dev-tools
```

For a fresh clone:

```bash
git clone --recurse-submodules https://github.com/Haaanky/didactic-winner
# or, after a plain clone:
git submodule update --init
```

### What the submodule provides

| File | Purpose |
|---|---|
| `src/generate_asset.sh` | CLI generator (cloud → local fallback) |
| `src/servers/local_sprite_server.py` | AUTOMATIC1111-compatible sprite server |
| `src/servers/local_audio_server.py` | AudioCraft SFX/music server |
| `docs/AI_BACKENDS.md` | Backend selection rules (mirrors `AI_BACKENDS.md` at root) |
| `config/.env.example` | Environment variable template |

### Important: background removal gap

The submodule does **not** call `remove_bg.py`. The project wrapper handles
this automatically — do not bypass the wrapper to call the submodule script
directly unless you call `remove_bg.py` yourself afterward.

---

## §2 — Tier 2: Internal copy (`tools/_generate_asset_internal.sh`)

**Path:** `tools/_generate_asset_internal.sh`

A project-local copy of the generator that includes the `_strip_sprite_bg`
call directly. It is activated when:
- The submodule has not been initialised, **or**
- The submodule script exits non-zero, **or**
- `FORCE_INTERNAL=1` is set

This copy should be kept roughly in sync with the submodule. When the
submodule is updated, review whether `_generate_asset_internal.sh` needs
the same changes, then update it in the same commit.

**Do not remove this file** until the submodule has been running without
failures in production for at least one release cycle.

---

## §3 — Tier 3: Local AI servers

Local servers are embedded inside tiers 1 and 2 — they are the final fallback
within each tier when cloud APIs are unavailable or fail.

| Server | Default port | Script |
|---|---|---|
| Sprite (AUTOMATIC1111) | 7860 | `vendor/game-dev-tools/src/servers/local_sprite_server.py` |
| Audio / Music (AudioCraft) | 8080 | `vendor/game-dev-tools/src/servers/local_audio_server.py` |

Override ports with `LOCAL_SPRITE_URL`, `LOCAL_SFX_URL`, `LOCAL_MUSIC_URL`.
Auto-start with `LOCAL_SPRITE_START_CMD`, `LOCAL_SFX_START_CMD`, `LOCAL_MUSIC_START_CMD`.

**CRITICAL:** Never start local servers from a Claude cloud session.
See `AI_BACKENDS.md` for the full rule and reasoning.

---

## §4 — Tier 4: Agent Built-in Skills Fallback

**This tier is for AI agents (Claude) only.** It is activated when all three
automated tiers have failed and the agent must still produce an asset to
unblock development.

### When to use this tier

Use tier 4 only when ALL of the following are true:
1. The submodule script exited non-zero or is not present
2. The internal fallback script exited non-zero or is not present
3. No cloud API keys are available in the environment
4. Local servers are not running and cannot be started (cloud session)

### What Claude can generate as built-in skills

| Asset type | Technique | Quality | Notes |
|---|---|---|---|
| Sprite (static) | SVG → PNG via Python `cairosvg` or `Pillow` | Placeholder | Simple geometric shapes, solid colours — sufficient for layout/collision |
| Sprite (animated) | Python `Pillow` multi-frame PNG/GIF | Placeholder | Limited to simple animations |
| SFX | Python `wave` + `math` (sine/square tones) | Minimal | Beep/click/thud approximations; no realism |
| Music | Python `wave` chord generation | Minimal | Chord stabs only; not suitable for final audio |

### Procedure for tier 4 (agent instructions)

1. **State the fallback explicitly.** Inform the developer: *"All automated
   generators failed. Generating a placeholder asset using built-in Python
   capabilities. This must be replaced with a properly generated asset
   before shipping."*

2. **Generate a minimal placeholder** using one of the techniques above.
   Clearly name the file with a `_placeholder` suffix:
   ```
   assets/generated/sprite_campfire_placeholder_<timestamp>.png
   ```

3. **Register it as a placeholder** in `assets/registry.json` with
   `"generation_tool": "agent-placeholder"` and add a comment field:
   ```json
   {
     "name": "campfire_sprite_placeholder",
     "type": "sprite",
     "file_path": "assets/generated/sprite_campfire_placeholder_1234567890.png",
     "generation_tool": "agent-placeholder",
     "created": "2026-03-26",
     "note": "PLACEHOLDER — replace with generated asset before release"
   }
   ```

4. **Do NOT commit placeholder assets** — they are gitignored under
   `assets/generated/`. Leave a `# TODO: regenerate` comment in the
   scene or script that references the placeholder.

5. **Report to the developer** what needs to be done to get the real asset:
   ```
   To generate the real asset, run one of:
     A) git submodule update --init vendor/game-dev-tools && ./tools/generate_asset.sh sprite "..."
     B) Set OPENAI_API_KEY in .env and run ./tools/generate_asset.sh sprite "..."
   ```

### Weighing tier 4 vs tier 3 local servers

If tier 3 local servers are available but the agent is running in a cloud
session, prefer tier 4 (generate a simple placeholder) over attempting to
start local servers. Tier 3 local servers require the developer's machine
and will time out in a cloud environment.

---

## §5 — Background Removal

After any sprite generation from tiers 1 or 2, the wrapper runs:

```bash
python3 tools/remove_bg.py <saved_file>
```

This strips white/near-white backgrounds using a flood-fill from the image
corners with configurable fuzz. See `tools/remove_bg.py` for algorithm details.

**The submodule does not include `remove_bg.py`.** This is intentional —
background removal is project-specific. The file lives in `tools/remove_bg.py`
and must not be removed while tiers 1 or 2 are active.

If background removal fails (non-zero exit from `remove_bg.py`), the wrapper
logs a warning but does **not** fail the overall generation — the file is
saved with its original background and the developer is notified.

Set `SKIP_REMOVE_BG=1` to suppress background removal entirely (testing only).

---

## §6 — Running the Tests

### Shell tests (all platforms)

```bash
bash tests/shell/test_asset_wrapper.sh
```

Covers: submodule delegation, `ASSET_OUTPUT_DIR` forwarding, remove_bg.py
invocation, internal fallback, `FORCE_INTERNAL`, `SKIP_REMOVE_BG`, and
graceful failure when all generators are absent.

### GUT tests (Godot editor or headless)

```bash
# Headless (CI)
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit \
  -ginclude_subdirs -gexit

# Editor
# Open GUT dock → Run All
```

The GUT test file `tests/unit/test_asset_submodule.gd` verifies filesystem
structure: submodule registration in `.gitmodules`, script presence, wrapper
content, architecture doc presence.

---

## §7 — Maintenance

### Updating the submodule

```bash
cd vendor/game-dev-tools
git pull origin main
cd ../..
git add vendor/game-dev-tools
git commit -m "Update game-dev-tools submodule to <version>"
```

After updating, check whether `tools/_generate_asset_internal.sh` needs the
same changes. Update it in the same commit if so.

### Removing the internal fallback

Once the submodule has been running without issues for one release cycle, the
internal fallback can be removed:

1. Delete `tools/_generate_asset_internal.sh`
2. Update `tools/generate_asset.sh` to remove the tier-2 block
3. Update this document
4. Run shell tests and GUT tests — all must pass before pushing

### Removing the submodule

If `game-dev-tools` is ever inlined or replaced:

```bash
git submodule deinit vendor/game-dev-tools
git rm vendor/game-dev-tools
rm -rf .git/modules/vendor/game-dev-tools
# Update tools/generate_asset.sh to remove tier-1 block
```
