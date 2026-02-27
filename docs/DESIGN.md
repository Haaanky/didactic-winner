# Design Proposal
## Dudes in Alaska
**Version:** 1.0
**Date:** 2026-02-27

---

## Table of Contents

1. [Technology Stack](#1-technology-stack)
2. [Architecture Overview](#2-architecture-overview)
3. [Scene Architecture](#3-scene-architecture)
4. [Core Systems Design](#4-core-systems-design)
5. [Art Direction](#5-art-direction)
6. [Audio Design](#6-audio-design)
7. [UI/UX Design](#7-uiux-design)
8. [Free Asset Sources](#8-free-asset-sources)
9. [Development Roadmap](#9-development-roadmap)

---

## 1. Technology Stack

All tools are **100% free and open-source**. No subscriptions, royalties, or paid licenses.

### 1.1 Engine
| Tool | Purpose | License |
|------|---------|---------|
| **Godot 4** | Game engine, scripting, physics, rendering | MIT |
| **GDScript** | Scripting language | MIT (built-in) |

### 1.2 Art & Assets
| Tool | Purpose | License |
|------|---------|---------|
| **Aseprite** *(or LibreSprite)* | Pixel art sprite creation | GPL / MIT |
| **GIMP** | General image editing | GPL |
| **Inkscape** | Vector art (UI elements, map) | GPL |
| **Tiled** *(or Godot's built-in TileMapLayer)* | Tilemap level design | GPL |

> **Note:** Aseprite is paid ($20) but LibreSprite is its free/open-source fork. Godot 4 also has a built-in sprite editor sufficient for prototyping.

### 1.3 Audio
| Tool | Purpose | License |
|------|---------|---------|
| **LMMS** | Music composition (DAW) | GPL |
| **Audacity** | Sound effect editing | GPL |
| **sfxr / jfxr** | Procedural SFX generation | MIT |
| **freesound.org** | Free CC0 ambient sounds | CC0/CC BY |

### 1.4 Version Control & Workflow
| Tool | Purpose |
|------|---------|
| **Git** | Version control |
| **GitHub** | Remote hosting (free tier) |

---

## 2. Architecture Overview

The game uses Godot 4's **node composition** model. All major systems are implemented as **Autoload singletons** or **independent scene components** to keep coupling minimal.

```
Game
├── Autoloads (singletons)
│   ├── GameManager          — global state, game loop
│   ├── TimeManager          — day/night, seasons
│   ├── WeatherManager       — weather events
│   ├── AudioManager         — music + sfx bus
│   └── SaveManager          — save/load
│
├── World (main scene)
│   ├── TileMapLayer         — terrain tiles
│   ├── ResourceSpawner      — trees, rocks, plants
│   ├── AnimalManager        — wildlife population
│   └── LightingLayer        — day/night overlay
│
├── Player
│   ├── PlayerController     — movement, input
│   ├── NeedsSystem          — hunger/warmth/rest/morale
│   ├── Inventory            — items + weight
│   ├── SkillSystem          — skill XP + levels
│   └── HUD                  — on-screen UI
│
├── Homestead
│   ├── BuildingSystem       — place/remove structures
│   └── Structures/          — individual structure scenes
│
└── UI (screens)
    ├── MainMenu
    ├── InventoryScreen
    ├── CraftingScreen
    ├── MapScreen
    ├── Journal
    └── PauseMenu
```

---

## 3. Scene Architecture

### 3.1 Player Scene
```
PlayerController (CharacterBody2D)
├── AnimatedSprite2D        — 8-direction sprites per action
├── CollisionShape2D        — hitbox
├── NeedsComponent (Node)   — hunger/warmth/rest/morale logic
├── InventoryComponent (Node)
├── SkillComponent (Node)
├── InteractRay (RayCast2D) — detects interactable objects
├── HeatDetector (Area2D)   — detects nearby heat sources
└── AudioStreamPlayer2D     — footstep sounds
```

**Key signals:**
```gdscript
signal needs_changed(need: String, value: float)
signal item_picked_up(item: ItemData)
signal skill_leveled_up(skill: String, new_level: int)
signal player_died()
```

### 3.2 World Scene
```
World (Node2D)
├── TileMapLayer            — ground, paths, snow overlay
├── TileMapLayer            — decorations (grass tufts, rocks)
├── TreeManager (Node)      — manages tree instances + regrowth
├── ResourceNodes (Node)    — rock deposits, berry bushes
├── AnimalManager (Node)    — spawns/despawns animals
├── WeatherParticles (CPUParticles2D) — snow, rain
└── DayNightOverlay (CanvasModulate) — colour-graded day/night
```

### 3.3 Structure Scenes (examples)
```
LogCabin (StaticBody2D)
├── Sprite2D                — stage-based sprite (5 build stages)
├── CollisionShape2D
├── InsulationArea (Area2D) — warmth zone inside cabin
├── InteractPoint (Node2D)  — entry/exit trigger
└── StorageComponent (Node) — chest inventory

Campfire (Node2D)
├── AnimatedSprite2D        — fire animation
├── HeatArea (Area2D)       — detected by player HeatDetector
├── Light2D                 — dynamic light
├── AudioStreamPlayer2D     — crackling sound
└── FuelComponent (Node)    — burns wood over time
```

---

## 4. Core Systems Design

### 4.1 Needs System

Each need is a float [0.0, 100.0]. All needs drain at a base rate per in-game hour. Rates are modified by environment and activity.

```gdscript
class_name NeedsComponent
extends Node

signal need_changed(need: String, value: float)
signal need_critical(need: String)

const DRAIN_RATES := {
    "hunger":  2.0,   # per in-game hour
    "warmth":  1.5,
    "rest":    1.8,
    "morale":  0.5
}

var needs := {
    "hunger":  100.0,
    "warmth":  100.0,
    "rest":    100.0,
    "morale":  100.0
}
```

**Modifier examples:**
- Blizzard: warmth drain ×3.0
- Inside heated cabin: warmth drain ×0.1
- Resting in bed: rest regenerates at +10/hour
- Eating good meal: morale +20 burst

### 4.2 Weather & Temperature System

`WeatherManager` (Autoload) maintains:
- `current_temperature: float` — world temp in °C equivalent (-30 to +25)
- `current_weather: WeatherType` — enum: CLEAR, OVERCAST, RAIN, SNOW, BLIZZARD

Temperature is driven by season + time of day:
```
Base temp = SeasonBase[season] + TimeOffset[hour]
Actual temp = Base temp + WeatherModifier[weather]
```

Season base temperatures:
| Season | Day | Night |
|--------|-----|-------|
| Spring | +8  | -5   |
| Summer | +18 | +5   |
| Autumn | +2  | -10  |
| Winter | -15 | -28  |

### 4.3 Building System

Buildings use a **stage-based construction model**:

```gdscript
class_name BuildingStage
extends Resource

@export var stage_name: String
@export var required_materials: Array[ItemCount]
@export var sprite_frame: int
@export var time_to_build: float  # in-game minutes
```

The `BuildingSystem` autoload handles:
- Ghost preview (translucent placement preview)
- Collision validation (no overlap, within plot)
- Material deduction from inventory
- Stage progression

### 4.4 Time System

`TimeManager` (Autoload) drives all time-dependent systems:

```gdscript
class_name TimeManager
extends Node

signal hour_passed(hour: int)
signal day_passed(day: int)
signal season_changed(season: Season)

const REAL_SECONDS_PER_GAME_HOUR := 60.0  # 1 min real = 1 hr game

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var game_hour: int = 8
var game_day: int = 1
var current_season: Season = Season.SPRING
```

All systems (needs drain, food spoilage, tree regrowth, animal spawning) subscribe to `hour_passed` and `day_passed` signals.

### 4.5 Inventory System

Weight-based inventory using Godot Resources:

```gdscript
class_name ItemData
extends Resource

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var weight: float
@export var max_stack: int = 1
@export var category: ItemCategory
@export var food_value: float = 0.0
@export var warmth_value: float = 0.0
```

Items are defined as `.tres` resource files — easy to add new items without code changes.

### 4.6 Skill System

Skills use an XP curve. Each skill level provides passive bonuses:

| Skill | Level 1 | Level 5 |
|-------|---------|---------|
| Lumberjack | +0% yield | +50% yield, -30% time |
| Fishing | Base catch | +40% rate, rare fish |
| Hunting | Basic tracking | Silent movement, 1-shot kills |
| Cooking | Simple recipes | Complex recipes, -20% ingredients |
| Crafting | Basic tools | Advanced tools unlocked |

### 4.7 Save System

Uses Godot's `FileAccess` to write JSON save files to the user data directory:

```
user://saves/
    slot_1.json
    slot_2.json
    slot_3.json
```

Save data includes: world state, player needs/inventory/skills, time/season, homestead structure positions and stages, resource node states.

---

## 5. Art Direction

### 5.1 Style
**16×16 or 32×32 pixel art**, top-down perspective (slight top-down angle, not pure overhead).

Inspired by:
- *Stardew Valley* — cosy pixel art, readable tiles
- *The Long Dark* — Alaska colour palette (cold blues, warm oranges near fire)
- *Don't Starve* — hand-crafted character expressions

### 5.2 Colour Palette

**Season palettes:**
| Season | Sky | Ground | Accent |
|--------|-----|--------|--------|
| Spring | Pale blue | Brown/green | Mud puddles |
| Summer | Bright blue | Rich green | Wildflowers |
| Autumn | Grey-orange | Orange/red | Fallen leaves |
| Winter | Dark blue-grey | White/grey | Fire warmth |

**Character (The Dude):**
- Plaid shirt, work boots, jeans → summer
- Heavy jacket, fur hat, boots → winter
- All clothing equippable/visible on sprite

### 5.3 Tile Set Plan
```
terrain_tiles.png    — grass, dirt, snow, ice, water, rock
trees.png            — conifer (small/medium/large/stump), deciduous
structures.png       — cabin stages, campfire, workbench, smokehouse, etc.
objects.png          — fish, logs, rocks, berry bush, traps
characters.png       — dude (8 directions × actions), animals (moose, rabbit, etc.)
ui.png               — HUD bars, icons, journal frame
```

---

## 6. Audio Design

### 6.1 Music
- **Composition style:** Acoustic guitar, light piano, ambient texture
- **Tracks:**
  - `main_menu.ogg` — relaxed, welcoming
  - `summer_day.ogg` — bright, light
  - `winter_day.ogg` — sparse, slightly tense
  - `cabin_interior.ogg` — warm, crackling undertone
  - `blizzard.ogg` — wind-heavy, minimal melody
- **Implementation:** Crossfade between tracks based on season + location using `AudioManager`

### 6.2 Sound Effects (key SFX)
```
axe_chop_*.ogg       — 3 variations
wood_thud.ogg
fish_splash.ogg
fishing_line.ogg
rifle_shot.ogg
footstep_snow_*.ogg  — 4 variations
footstep_wood.ogg
fire_crackle_loop.ogg
blizzard_wind_loop.ogg
ui_click.ogg
item_pickup.ogg
level_up.ogg
```

All SFX sourced from freesound.org (CC0) or generated with jfxr.

---

## 7. UI/UX Design

### 7.1 HUD Layout
```
┌─────────────────────────────────────────────────┐
│ [Day 14]  [Summer]  [14:32]          [❤❤❤❤❤]   │
│                                                   │
│                   GAME WORLD                      │
│                                                   │
│ [🍗 Hunger  ████████░░]  [🔥 Warmth  ███████░░░] │
│ [💤 Rest    █████░░░░░]  [😄 Morale  ██████████] │
│                                      [Axe 🪓]    │
└─────────────────────────────────────────────────┘
```

### 7.2 Inventory Screen
- Grid-based, 6×8 slots
- Weight bar at top (current/max)
- Tabs: All / Food / Tools / Materials / Clothing
- Right-click context menu: Use / Equip / Drop / Inspect

### 7.3 Crafting Screen
- Split view: available recipes (left), selected recipe detail + craft button (right)
- Greyed-out recipes show what you're missing
- Filter by category

### 7.4 Map
- Hand-drawn art style (parchment look)
- Player position shown as small icon
- Discovered locations can be right-clicked to place custom markers
- Not auto-revealed — player must explore

### 7.5 Journal
- Pages of scrawled handwriting style font
- Auto-logs: catches, hunts, buildings completed, firsts (first winter survived, etc.)
- Written in first-person "dude voice" — casual, humorous

---

## 8. Free Asset Sources

| Source | Content | License |
|--------|---------|---------|
| [OpenGameArt.org](https://opengameart.org) | Sprites, tiles, music, SFX | CC0/CC-BY |
| [freesound.org](https://freesound.org) | Sound effects, ambient | CC0/CC-BY |
| [itch.io free assets](https://itch.io/game-assets/free) | Pixel art packs | Varies (check per asset) |
| [Kenny.nl](https://kenney.nl/assets) | UI elements, icons | CC0 |
| [LMMS](https://lmms.io) | Music DAW | GPL |
| [LibreSprite](https://libresprite.github.io) | Pixel art editor | GPL |
| [GUT (Godot Unit Testing)](https://github.com/bitwes/Gut) | Testing framework | MIT |

---

## 9. Development Roadmap

### Phase 1 — Foundation (MVP vertical slice)
- [ ] Godot 4 project initialized, `.gitignore` configured
- [ ] Input Map actions defined
- [ ] World tilemap (static hand-crafted map, summer biome only)
- [ ] Player movement (8-direction)
- [ ] Needs system (all 4 needs, HUD display)
- [ ] Day/Night cycle + basic lighting
- [ ] Tree chopping (axe tool, logs drop)
- [ ] Campfire (place, fuel, warmth area)
- [ ] Basic inventory (pick up items, weight limit)
- [ ] Save/Load (single slot)

### Phase 2 — Core Loop
- [ ] Full season system (4 seasons, temperature, visual transitions)
- [ ] Weather events (snow, blizzard, rain)
- [ ] Log cabin construction (5 stages)
- [ ] Workbench + tool crafting
- [ ] Fishing (summer rod fishing minigame)
- [ ] Basic cooking (campfire + wood stove)
- [ ] Food spoilage system
- [ ] Skill system (lumberjack + fishing)

### Phase 3 — Content Expansion
- [ ] Hunting (trapping + rifle)
- [ ] Ice fishing (winter)
- [ ] Animal population system
- [ ] Hide crafting (winter clothing)
- [ ] Smokehouse + food preservation
- [ ] Additional structures (woodshed, outhouse, fishing shack)
- [ ] Map screen + journal
- [ ] Foraging (berries, mushrooms, herbs)
- [ ] Morale system (events, meals, weather)

### Phase 4 — Polish
- [ ] Complete audio (music + SFX)
- [ ] Particle effects (snow, rain, fire sparks, footprints)
- [ ] Animated sprite polish (all 8-direction actions)
- [ ] Settings screen (volume, keybinds, display)
- [ ] Multiple save slots
- [ ] Main menu
- [ ] Linux/macOS/Windows export builds
- [ ] Bug fixing + balancing pass

---

## Summary: Why Godot 4?

| Criterion | Godot 4 | Unity (free tier) | GameMaker |
|-----------|---------|-------------------|-----------|
| License | MIT (truly free) | Proprietary (runtime fees risk) | Proprietary |
| 2D workflow | Excellent | Good | Excellent |
| GDScript learning curve | Low (Python-like) | Medium (C#) | Medium (GML) |
| Community & docs | Strong | Very strong | Good |
| Export to Linux/Mac/Win | Free, built-in | Free | Paid for some |
| Version control friendly | Yes (text scenes) | Partially | Partially |
| **Verdict** | **Best choice** | Revenue-share risk | Paid exports |

Godot 4 is the **clear winner** for a zero-budget, open-source, multi-platform 2D game. It is actively maintained, has no royalty model, and its text-based scene format works perfectly with Git.
