# Asset Generation Policy — Dudes in Alaska

## Purpose

This document instructs Claude Code on how to handle asset requirements when working in this repository. Any prompt that introduces, modifies, or replaces content that has a visual, audio, or interactive representation must trigger automatic asset generation using the project's configured tools (`tools/generate_asset.sh` for CLI, or the **AI Asset Generator** editor plugin).

---

## Asset Registry

The asset registry is located at `assets/registry.json` in the repository root.

Each entry must contain: asset name, type, file path, generation tool, and creation date.

- If the file does not exist, create it before registering the first asset.
- If the file exists but is malformed, report this to the developer and pause all asset operations.

### Registry entry schema

```json
{
  "name": "campfire_sprite",
  "type": "sprite",
  "file_path": "assets/sprites/campfire_sheet.png",
  "generation_tool": "openai-dalle3",
  "created": "2026-03-24"
}
```

**Generation tool values:** `openai-dalle3` (sprites), `elevenlabs` (SFX), `replicate-suno` (music), `manual` (hand-crafted), `unknown` (pre-existing, untracked).

---

## Trigger Conditions

Asset generation must be triggered when a prompt:

- Introduces a new game object, character, item, vehicle, prop, or UI element — e.g. adding a moose, a new weapon, a crafting table, or a HUD icon
- Modifies the **visual appearance**, **audio**, or **player-facing interaction** of an existing object (internal logic changes, parameter tuning, and collision adjustments do **not** trigger generation)
- Adds a new in-game event, action, or milestone that would benefit from audio or visual feedback (sound stinger on item pickup, music change on season transition, etc.)
- Replaces or removes an existing asset — the replacement must be generated **before** the old one is removed

Do not skip asset generation based on assumptions about existing assets. Check `assets/registry.json` and the file structure first. If the asset is not registered and not present on disk, generate it.

---

## Asset Inference Rules

When an asset-triggering prompt is received, infer the **full set** of required assets from context. Do not generate only the explicitly mentioned asset — reason about what a complete, polished implementation would require.

**Example prompt:** *"Add a canoe the player can paddle on rivers."*

Required asset inference:
- Sprite: canoe idle (stationary on water)
- Sprite: canoe paddling animation frames
- SFX: paddle stroke through water
- SFX: canoe hull bumping against shore/rocks
- Music stinger: short discovery jingle on first boarding

**If the total number of inferred assets exceeds 5**, list all inferred assets and their intended generation tool, then pause and await developer confirmation before proceeding.

---

## Generation Workflow

1. Parse the prompt and identify all implied asset requirements.
2. For each required asset, determine the appropriate tool:

   | Asset category | Tool | CLI invocation |
   |---|---|---|
   | Sprites / textures / icons | OpenAI DALL-E 3 | `./tools/generate_asset.sh sprite "<prompt>"` |
   | Sound effects / ambient loops | ElevenLabs | `./tools/generate_asset.sh sfx "<prompt>"` |
   | Music tracks / stingers | Replicate (Suno) | `./tools/generate_asset.sh music "<prompt>"` |

3. Generate all assets **before** implementing the feature that depends on them.
4. Place generated assets in the correct directories:

   | Asset type | Directory | Format |
   |---|---|---|
   | Sprites | `assets/sprites/` or `assets/generated/` | `.png` (transparent background, see below) |
   | SFX | `assets/audio/` | `.wav` |
   | Music | `assets/audio/` | `.ogg` |

5. Register each new asset in `assets/registry.json`.
6. Report all generated assets to the developer using the following format **before** proceeding with implementation:

   | Asset name | Type | File path | Tool used | Status |
   |------------|------|-----------|-----------|--------|
   | `campfire_sprite` | sprite | `assets/sprites/campfire_sheet.png` | openai-dalle3 | ✅ generated |
   | `campfire_crackle` | sfx | `assets/audio/campfire_crackle.wav` | elevenlabs | ✅ generated |

---

## Sprite Transparency — Mandatory

Every sprite used in-game must have a **transparent background**. White background boxes are never acceptable.

- `generate_asset.sh` runs `tools/remove_bg.py` automatically — do not bypass this step.
- If a sprite is added manually, run `python3 tools/remove_bg.py <file.png>` before committing.
- After background removal, confirm in Godot's FileSystem dock that the background is transparent, not white.
- If removal leaves a visible fringe, re-generate with a higher-contrast prompt (e.g. add `"dark background"` or `"black background"`) and re-run the removal tool.

---

## Scope and Coverage

These rules apply to all asset categories used in **Dudes in Alaska**, including:

- **Visual:** sprites, sprite sheets, tileset tiles, icons, UI elements, animations
- **Audio:** sound effects, ambient loops, seasonal music tracks, event stingers
- **Data:** generated configuration or localisation strings tied to the new feature

If a required asset category has **no configured generation tool**, report this to the developer and pause generation for that category — do not skip silently.

---

## Modifying Existing Assets

If a prompt modifies an existing game object or feature:

- Generate new or updated assets to reflect the change.
- Do not reuse old assets unless explicitly instructed to do so.
- Flag any old assets that are now orphaned and ask the developer whether to delete them.
- Update the corresponding entry in `assets/registry.json`.

---

## Dudes in Alaska — Asset Naming Conventions

Follow the project's `snake_case` file naming rules (see `CLAUDE.md §10`).

Suggested naming patterns per category:

| Category | Pattern | Example |
|---|---|---|
| Character sprites | `<character>_sheet.png` | `player_sheet.png`, `moose_sheet.png` |
| Environment sprites | `environment/<name>.png` | `environment/birch_large.png` |
| Object sprites | `<object>.png` | `campfire_sheet.png`, `bicycle.png` |
| SFX | `<action>_<subject>.wav` | `footstep_snow.wav`, `fish_catch.wav` |
| Music | `<mood_or_season>.ogg` | `winter_outdoor.ogg`, `autumn_day.ogg` |

---

## Ambiguity Handling

If it is unclear whether a prompt requires asset generation, **err on the side of generating**. State the assumption explicitly before proceeding.

**Example:** *"Add a trap for catching small animals."*
> Assumption: this introduces a new game object with a visual representation and interaction feedback. Inferring required assets: trap idle sprite, trap triggered sprite, SFX for snap/trigger. Proceeding unless instructed otherwise.

---

## Integration with CLAUDE.md

This policy is a mandatory extension of `CLAUDE.md`. The rules in both files apply simultaneously. In case of conflict, the more restrictive rule takes precedence. Re-read both files at the start of every session.
