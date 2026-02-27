# Design Proposal
## Dudes in Alaska
**Version:** 2.0
**Date:** 2026-02-27
**Based on:** Sips' full Dude Sim: Alaska pitch transcript (Pitch, Please, Aug 9 2020)

---

## Table of Contents

1. [Technology Stack](#1-technology-stack)
2. [Architecture Overview](#2-architecture-overview)
3. [Scene Hierarchy](#3-scene-hierarchy)
4. [Core Systems Design](#4-core-systems-design)
5. [Long-term Projects — Implementation Notes](#5-long-term-projects--implementation-notes)
6. [Art Direction](#6-art-direction)
7. [Audio Design](#7-audio-design)
8. [UI/UX Design](#8-uiux-design)
9. [Free Asset Sources](#9-free-asset-sources)
10. [Development Roadmap](#10-development-roadmap)

---

## 1. Technology Stack

All tools are **100% free and open-source**.

### 1.1 Engine
| Tool | Purpose | License |
|------|---------|---------|
| **Godot 4** | Engine, 2D renderer, physics, scripting | MIT |
| **GDScript** | Primary scripting language | MIT (built-in) |

### 1.2 Art
| Tool | Purpose | License |
|------|---------|---------|
| **LibreSprite** | Pixel art sprites and tiles | GPL |
| **GIMP** | General image editing | GPL |
| **Inkscape** | Vector UI elements, map | GPL |
| **Godot TileMapLayer** | Tilemap level design | MIT (built-in) |

### 1.3 Audio
| Tool | Purpose | License |
|------|---------|---------|
| **LMMS** | Music composition (acoustic/ambient DAW) | GPL |
| **Audacity** | SFX editing | GPL |
| **jfxr** | Procedural SFX generation (UI sounds, small effects) | MIT |
| **freesound.org** | Ambient loops, nature sounds | CC0 / CC-BY |

### 1.4 Version Control
| Tool | Purpose |
|------|---------|
| **Git + GitHub** | Version control; free tier sufficient |

---

## 2. Architecture Overview

The game uses Godot 4's **node composition** model. Global state lives in **Autoload singletons**. All gameplay systems are **self-contained scenes** that communicate via **signals** — no direct cross-scene `get_node()` chains.

```
Game
├── Autoloads (singletons — always loaded)
│   ├── GameManager          — global state, pause, difficulty mode
│   ├── TimeManager          — hour/day/season advancement
│   ├── WeatherManager       — temperature, weather events
│   ├── AudioManager         — music + sfx bus management
│   ├── SaveManager          — serialise/deserialise world state
│   └── EventBus             — global signal relay for decoupled systems
│
├── World (main scene)
│   ├── TileMapLayer[ground] — terrain base (grass, snow, dirt, ice, rock)
│   ├── TileMapLayer[deco]   — decorations (moss, pebbles, footprints overlay)
│   ├── TileMapLayer[snow]   — dynamic snow accumulation layer
│   ├── PathManager          — tracks usage, manages overgrowth, peg markers
│   ├── ResourceManager      — trees, rock deposits, berry bushes
│   ├── AnimalManager        — wildlife spawning, behaviour, populations
│   ├── WeatherParticles     — snow, rain, fog particles
│   ├── DayNightLayer        — CanvasModulate colour grade
│   └── EnvStorySpawner      — places environmental storytelling set-dressing
│
├── Player
│   ├── PlayerController     — movement, input, interaction
│   ├── NeedsComponent       — hunger/warmth/rest/morale + health
│   ├── InventoryComponent   — weight-based item management
│   ├── SkillComponent       — XP tracking for all 9 skills
│   ├── AppearanceComponent  — beard/hair growth, dirt, clothing state
│   └── HUD (CanvasLayer)    — needs display, hotbar, context prompts
│
├── Homestead (dynamic scene)
│   ├── BuildingSystem       — blueprint placement, material supply, stage advance
│   ├── PathMarkerSystem     — peg-and-rope marker placement
│   └── Structures/          — individual structure scenes (instantiated at runtime)
│
├── Town (scene, loaded on proximity)
│   ├── NPCManager           — familiarity tracking, dialogue state
│   ├── NoticeBoard          — mission list
│   ├── Shops/               — general store, clothes shop, vet
│   └── Museum               — tracks player donations
│
└── UI (CanvasLayer screens, toggled)
    ├── InventoryScreen
    ├── CraftingScreen
    ├── MapScreen
    ├── JournalScreen
    ├── PhotoMode
    └── PauseMenu
```

---

## 3. Scene Hierarchy

### 3.1 Player Scene
```
PlayerController (CharacterBody2D)
├── AnimatedSprite2D         — 8-direction × action sprite sheet
├── CollisionShape2D
├── NeedsComponent (Node)
├── InventoryComponent (Node)
├── SkillComponent (Node)
├── AppearanceComponent (Node)
├── InteractRay (RayCast2D)  — detects world interactables
├── HeatDetector (Area2D)    — detects nearby fire/heat sources
└── AudioStreamPlayer2D      — footstep variation sounds
```

**Key player signals:**
```gdscript
signal need_depleted(need: String)
signal item_picked_up(item: ItemData)
signal skill_leveled_up(skill: String, new_level: int)
signal player_died()
signal interacted_with(target: Node)
```

### 3.2 Structure Scene (base)
```
Structure (Node2D)
├── Sprite2D / AnimatedSprite2D   — stage-based visual
├── CollisionShape2D              — physical presence
├── BuildStageComponent (Node)    — current stage, material requirements
├── WeatherDamageComponent (Node) — tracks deterioration
└── InteractPoint (Area2D)        — player interaction trigger
```

Specific structures extend this base with additional components (e.g. `HeatComponent` for fire/stoves, `StorageComponent` for chests, `InsulationArea` for the cabin).

### 3.3 Animal Scene (base)
```
Animal (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── NavigationAgent2D
├── AnimalBehaviourComponent     — state machine: idle/wander/flee/hunt
├── ComfortRadiusComponent       — tracks acclimatisation to player proximity
└── AudioStreamPlayer2D          — ambient animal sounds
```

---

## 4. Core Systems Design

### 4.1 Time System (`TimeManager` Autoload)

All time-dependent systems subscribe to signals from `TimeManager`. Nothing polls time directly.

```gdscript
class_name TimeManager
extends Node

signal hour_passed(hour: int)
signal day_passed(day: int)
signal season_changed(season: Season)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const REAL_SECONDS_PER_GAME_HOUR := 60.0

var game_hour: int = 8
var game_day: int = 1
var current_season: Season = Season.SPRING
var total_days_elapsed: int = 0
```

Subscribing systems:
- `NeedsComponent` → drains needs per hour
- `WeatherManager` → checks for weather event transitions
- `PathManager` → checks for path overgrowth
- `ResourceManager` → tree regrowth, plant respawn
- `AnimalManager` → animal migration at season change
- `AppearanceComponent` → hair/beard growth per day
- `FoodSpoilage` (on food items) → spoilage timer

### 4.2 Needs System (`NeedsComponent`)

```gdscript
class_name NeedsComponent
extends Node

signal need_changed(need: String, value: float)
signal need_critical(need: String)    # at 20%
signal need_depleted(need: String)    # at 0

const BASE_DRAIN_PER_HOUR := {
    "hunger": 4.0,
    "warmth": 2.0,
    "rest":   3.0,
    "morale": 0.8
}

var needs := { "hunger": 100.0, "warmth": 100.0, "rest": 100.0, "morale": 100.0 }
var health: float = 100.0
```

**Warmth modifiers (stacked multiplicatively):**
| Condition | Multiplier |
|-----------|-----------|
| Inside insulated cabin with stove | ×0.05 |
| Inside unheated cabin | ×0.4 |
| Blizzard outdoors | ×4.0 |
| Standard winter outdoors | ×2.0 |
| Summer outdoors | ×0.3 |
| Wet (rain/swimming) | ×1.8 |
| Full winter clothing | ×0.5 |

**Morale modifiers (flat bonuses/penalties per event):**
| Event | Morale |
|-------|--------|
| Hot meal (good cooking) | +20 burst |
| Eaten raw/uncooked | -10 |
| Blizzard day (outdoors) | -5/hr |
| Clear sunny day | +2/hr |
| Pet present and healthy | +1/hr |
| Isolation (no town visit > 30 days) | -0.5/hr |
| Won seasonal competition | +40 burst |
| First flight delivery arrives | +30 burst (once) |

### 4.3 Path System (`PathManager`)

The path system works on a usage-density map overlaid on the terrain.

- The map is divided into cells matching the tilemap grid
- Each cell has a `foot_traffic: float` value [0.0, 1.0]
- Player movement increments `foot_traffic` in cells they pass through
- Once `foot_traffic` reaches `PATH_THRESHOLD` (0.6), the cell displays a worn path tile
- Each in-game day, all cells decay by `DAILY_DECAY` (0.02)
- A cell with a peg marker has `decay_rate = 0` — never decays
- Peg markers are placeable items consumed from inventory

```gdscript
class_name PathManager
extends Node

const PATH_THRESHOLD := 0.6
const DAILY_DECAY := 0.02

var traffic_map: Dictionary  # Vector2i → float

func _on_player_moved(cell: Vector2i) -> void:
    traffic_map[cell] = minf(traffic_map.get(cell, 0.0) + 0.05, 1.0)
    _update_tile(cell)

func _on_day_passed(_day: int) -> void:
    for cell in traffic_map.keys():
        if not _has_peg_marker(cell):
            traffic_map[cell] = maxf(traffic_map[cell] - DAILY_DECAY, 0.0)
            _update_tile(cell)
```

### 4.4 Weather System (`WeatherManager`)

```gdscript
class_name WeatherManager
extends Node

signal weather_changed(new_weather: WeatherType)
signal temperature_changed(new_temp: float)

enum WeatherType { CLEAR, OVERCAST, RAIN, SNOW, BLIZZARD }

var current_temperature: float = 15.0
var current_weather: WeatherType = WeatherType.CLEAR
```

**Temperature formula:**
```
season_base = SEASON_DAY_TEMPS[season] if daytime else SEASON_NIGHT_TEMPS[season]
weather_offset = WEATHER_OFFSETS[current_weather]
current_temperature = season_base + weather_offset
```

Season base temperatures (°C):
| Season | Day | Night |
|--------|-----|-------|
| Spring | +8 | -5 |
| Summer | +18 | +5 |
| Autumn | +2 | -10 |
| Winter | -15 | -28 |

### 4.5 Building System (`BuildingSystem`)

Construction follows a **supply-then-place** loop:

1. Player selects a structure from the crafting menu
2. Ghost preview appears under cursor (green = valid placement, red = invalid)
3. Player confirms placement — blueprint is created at that position
4. Blueprint shows material requirements sidebar (R-82)
5. Player physically carries materials to the construction site
6. At site, player selects "Add materials" — materials move from inventory to site
7. Once threshold met, player selects "Build stage" — an in-progress build animation plays, the structure advances one stage
8. Repeat for each stage

Weather damage check runs daily. Structures below 100% completion in the `wall` or `roof` stage have a `damage_accumulation` that increases during rain/snow/blizzard.

```gdscript
func _on_day_passed(_day: int) -> void:
    for structure in active_structures:
        if not structure.is_complete() and not structure.has_treatment():
            var exposure: float = WeatherManager.get_weather_damage_rate()
            structure.apply_weather_damage(exposure)
```

### 4.6 Skill System (`SkillComponent`)

```gdscript
class_name SkillComponent
extends Node

signal skill_leveled_up(skill: String, new_level: int)

enum Skill {
    LUMBERJACKING, FISHING, HUNTING,
    TAXIDERMY, COOKING, CARPENTRY,
    MECHANICS, SEWING, FARMING
}

const MAX_LEVEL := 10
const XP_PER_LEVEL := 100.0

var skill_levels: Dictionary  # Skill → int
var skill_xp: Dictionary      # Skill → float

func add_xp(skill: Skill, amount: float) -> void:
    skill_xp[skill] += amount
    if skill_xp[skill] >= XP_PER_LEVEL:
        skill_xp[skill] -= XP_PER_LEVEL
        _level_up(skill)
```

Low-level skill failure states are visual and non-punishing: a level-1 taxidermy attempt produces a visibly bad mount (wrong proportions, googly eye placement). This is intentional — it is funny, not frustrating.

### 4.7 Appearance System (`AppearanceComponent`)

Tracks per-character cosmetic state. All values are saved.

```gdscript
class_name AppearanceComponent
extends Node

var hair_length: float = 0.0      # grows 1.0/day; max 10.0 before needing cut
var beard_length: float = 0.0     # grows 0.8/day; max 8.0
var dirt_level: float = 0.0       # 0=clean, 100=filthy; bathing resets
var clothing_slots: Dictionary    # slot_name → ClothingItem

# Affects sprite selection:
# hair_length + beard_length → selects beard/hair tier (3 tiers each)
# dirt_level → dirt overlay opacity
# clothing_slots → composite sprite layer stack
```

The player sprite is a **composite** of layered sprites: base body + hair tier + beard tier + each clothing slot + dirt overlay. Patchwork repairs on clothing add visible colour-mismatch patches to the clothing sprite.

### 4.8 Save System (`SaveManager`)

Uses Godot `FileAccess` with JSON serialisation. Each save records a snapshot of all persistent state.

```gdscript
const SAVE_DIR := "user://saves/"

func save(slot: int) -> void:
    var data := {
        "version": "1.0",
        "timestamp": Time.get_unix_time_from_system(),
        "time": TimeManager.serialise(),
        "weather": WeatherManager.serialise(),
        "player": _serialise_player(),
        "world": _serialise_world(),   # resource node states, path map, env story
        "homestead": _serialise_homestead(),
        "town": _serialise_town(),
        "pets": _serialise_pets()
    }
    FileAccess.open(SAVE_DIR + "slot_%d.json" % slot, FileAccess.WRITE)\
        .store_string(JSON.stringify(data))
```

---

## 5. Long-term Projects — Implementation Notes

These are the "killer features" of the game. They need to feel deeply satisfying.

### 5.1 The Car

The old car is a hand-placed world object. It is not procedurally generated. It is somewhere discoverable in the mid-game wilderness region.

**State machine for the car:**
```
UNDISCOVERED → DISCOVERED → [repair stages] → DRIVABLE
```

Repair stages (each requiring Mechanics XP + specific parts):
1. Assess (triggers part manifest — partial list, more revealed as skill grows)
2. Remove rusted/broken parts
3. Source replacement parts (find in world, scavenge, or order via helipad)
4. Install each part individually
5. First engine start (dramatic moment: first attempt may fail with lower Mechanics skill; succeeds with skill ≥ 5)

**Milestone moments:**
- Finding the car for the first time
- Getting the first engine component in place
- First engine turn-over (even if it fails)
- First successful engine start
- First drive

Each of these should have a small celebratory event: the journal auto-logs it, a short animation plays, a sound cue fires. These are the equivalent of Death Stranding's road-completion moments.

### 5.2 The Helipad

Clearing land for the helipad is a pure endurance project: chop all trees in a 10×10 tile area, level the ground, place landing markers.

**First delivery arrival:**
- A unique sound cue (distant helicopter) plays 5 in-game minutes before arrival
- The player can watch it land if present
- Cargo crates appear; the player manually carries them inside
- Journal entry: *"First supply drop. Didn't think I'd ever be this happy to see a box of nails."*

### 5.3 The Canoe

Lower stakes than the car but an earlier milestone. First opens up the river system.

- Craftable at Carpentry 4 using: 20 logs, 10 birch bark, pine resin (craftable from tree sap)
- Single-session build (takes ~2 in-game days of dedicated work)
- Milestone: first time the player paddles upstream and reaches an otherwise inaccessible area

---

## 6. Art Direction

### 6.1 Style
**32×32 pixel art**, top-down with a slight isometric-leaning angle (similar to Stardew Valley's perspective — not pure overhead, giving height/depth to trees and structures).

Mood board references:
- *Stardew Valley* — tile clarity, warm cosy palette
- *The Long Dark* — Alaska colour palettes (icy blues, deep greens, fire warmth)
- *My Self-Reliance* YouTube channel — rugged, lived-in aesthetic

### 6.2 Seasonal Palettes

| Season | Sky | Ground | Trees | Special |
|--------|-----|--------|-------|---------|
| Spring | Pale blue | Brown/green, mud | Early green buds | Snowmelt puddles |
| Summer | Bright blue | Rich green | Full canopy | Wildflowers, long shadows |
| Autumn | Grey-orange | Orange/amber | Red/gold foliage | Falling leaf particles |
| Winter | Dark blue-grey | White with depth shadows | Snow-capped | Fire warmth contrast, tracks in snow |

### 6.3 Character Sprite Design
The player sprite is **composite-layered** (see `AppearanceComponent`):
- Base body (4 seasonal base variants: light, medium, winter light, winter heavy)
- Hair tier overlay (3 lengths × colours)
- Beard tier overlay (3 lengths, optional)
- Clothing layer per slot (head, torso, legs, feet) — each has worn/patched states
- Dirt overlay (opacity scales with `dirt_level`)

8 directions × ~12 action states = ~96 animation sets. Prioritise: idle, walk, chop, fish, carry (heavy), sleep, interact.

### 6.4 Tile Set Plan
```
terrain.png        — grass (summer/spring/autumn), snow, ice, water, rock, dirt, mud
path_overlays.png  — worn path tiles (4 wear levels), peg markers
trees.png          — conifer (5 sizes + stump), birch (seasonal), deadfall
structures.png     — cabin (7 build stages), campfire, stove, workbench,
                     smokehouse, outhouse, fishing shack, taxidermy bench, helipad
objects.png        — fish, logs, rocks, berry bush (seasonal states), traps,
                     car (damage states), bicycle parts, canoe
animals.png        — moose, caribou, rabbit, ptarmigan, bear, fox, crow, deer, dog, cat
ui.png             — journal pages, map frame, HUD elements, icons
```

---

## 7. Audio Design

### 7.1 Music
Instrumentation: acoustic guitar, sparse piano, ambient textures (wind, water, crackling).

| Track | When | Mood |
|-------|------|------|
| `main_menu.ogg` | Main menu | Welcoming, curious |
| `spring_day.ogg` | Spring, outdoors | Hopeful, gentle |
| `summer_day.ogg` | Summer, outdoors | Bright, relaxed |
| `summer_night.ogg` | Summer, night outdoors | Calm, crickets layer |
| `autumn_day.ogg` | Autumn, outdoors | Melancholy, beautiful |
| `winter_outdoor.ogg` | Winter, outdoors | Sparse, tense undertone |
| `cabin_interior.ogg` | Inside cabin | Warm, safe, crackling fire layer |
| `blizzard.ogg` | During blizzard | Wind-dominated, minimal melody |
| `town.ogg` | In town | Folksy, social |
| `milestone.ogg` | First car start, first delivery, etc. | Brief, triumphant, emotional |

All tracks loop. `AudioManager` crossfades between tracks based on location + weather.

### 7.2 Key Sound Effects
```
axe_chop_[1-3].ogg          — wood chopping (3 variants, random)
log_thud.ogg                — log hitting ground
ice_crack.ogg               — ice fishing drill
fish_splash.ogg
footstep_snow_[1-4].ogg     — snow (4 variants)
footstep_grass_[1-3].ogg
footstep_wood.ogg           — cabin interior
campfire_loop.ogg
stove_crackle_loop.ogg
blizzard_wind_loop.ogg
helicopter_distant.ogg      — helipad delivery approach
engine_start_fail.ogg       — car first attempt
engine_start_succeed.ogg    — car first successful start (memorable)
notification_ping.ogg       — phone message received
level_up.ogg                — skill level up
journal_open.ogg
```

---

## 8. UI/UX Design

### 8.1 HUD (diegetic-default mode)

In diegetic mode, the player presses a key to "check" needs (the Dude looks at their phone / feels their stomach). On-screen display lasts 4 seconds then fades.

When a need is critical (<20%), a subtle persistent icon appears at the screen edge. This is the only permanent on-screen indicator in diegetic mode.

Non-diegetic mode (optional setting): standard need bars visible at all times.

```
[Diegetic — needs are hidden unless checked]

When critical only:
┌──────────────────────────────────────────────┐
│                                  ⚠ [🍗] [🔥] │
│              GAME WORLD                       │
│                                               │
│                                  [Season Day] │
└──────────────────────────────────────────────┘

When checked (fades after 4s):
┌──────────────────────────────────────────────┐
│ [🍗 ██████████ 84%]  [🔥 ████░░░░ 40%]       │
│ [💤 ███████░░░ 72%]  [😄 ██████████ 95%]      │
│                                               │
│              GAME WORLD                       │
└──────────────────────────────────────────────┘
```

### 8.2 Journal (primary quest log)
- Physical journal item in inventory
- Pages styled as handwritten text in a slightly scrawled font
- Each entry is in first-person dude voice (casual, occasionally dry/funny)
- Auto-entries for: milestones, first encounters with systems, season changes
- Manual entries: player can add a single line of custom text per in-game day
- Functions as the game's quest tracking (no separate quest UI)

Sample auto-entries:
> *"Day 4 — Built a lean-to. It's not much. It's mine."*
> *"Day 31 — First proper frost. That thing they call a cabin is going to need walls."*
> *"Day 89 — Found the car. Someone left a 1994 GMC out in the spruce. One day."*

### 8.3 Map
- Hand-drawn aesthetic (parchment, charcoal lines)
- Fog of war: only areas the player has visited are revealed
- Player position shown as a small icon
- Right-click to place named custom markers
- Not auto-updated with NPC locations — purely player's own notes on the world

### 8.4 Photo Mode
- Accessible at any time via keybind (does not pause time by default; can be set to pause)
- Camera: pan, tilt, FOV, depth of field
- Filters: none, film grain, vintage, desaturated, high contrast
- Photos saved to `user://photos/`
- In-game camera item: once obtained, lets player take in-world photographs that appear in the journal and can be printed/sold

### 8.5 Crafting Screen
- Triggered from workbench interaction
- Left panel: recipe categories (tools, structures, clothing, food, misc)
- Right panel: selected recipe, required materials (green = have, red = missing), Craft button
- Materials from inventory are automatically counted; missing materials show nearest source hint

---

## 9. Free Asset Sources

| Source | Content | License |
|--------|---------|---------|
| [opengameart.org](https://opengameart.org) | Sprites, tiles, music, SFX | CC0 / CC-BY |
| [freesound.org](https://freesound.org) | Ambient audio, nature sounds | CC0 / CC-BY |
| [kenney.nl](https://kenney.nl/assets) | UI icons, input icons | CC0 |
| [itch.io free assets](https://itch.io/game-assets/free) | Pixel art packs | Varies — check per asset |
| [LibreSprite](https://libresprite.github.io) | Pixel art editor | GPL |
| [LMMS](https://lmms.io) | Music DAW | GPL |
| [GUT](https://github.com/bitwes/Gut) | Godot unit testing | MIT |

---

## 10. Development Roadmap

Phases are ordered by player-facing value. Each phase ends with a playable vertical slice.

### Phase 1 — Foundation (first walking sim)
- [ ] Godot 4 project, `.gitignore`, input map defined
- [ ] World tilemap (summer biome, static hand-crafted map)
- [ ] Player movement (8-direction, basic stamina)
- [ ] Day/Night cycle with lighting
- [ ] `TimeManager` autoload with signals
- [ ] Needs system (4 needs, all drain over time, HUD)
- [ ] Tree chopping (axe → logs)
- [ ] Campfire (place from inventory, warmth area, fuel consumption)
- [ ] Basic inventory (pick up, weight limit, no UI yet)
- [ ] Manual save/load (single slot, JSON)

### Phase 2 — Survival Loop
- [ ] Full season system (4 seasons, temperature model, visual transitions)
- [ ] Weather events (snow, blizzard, rain particles + gameplay effects)
- [ ] Warmth modifier stack (outdoor temp → needs drain)
- [ ] Log cabin construction system (blueprint, stages, material supply)
- [ ] Woodshed + wood stove structure
- [ ] Fishing (summer rod, timing minigame, fish processing)
- [ ] Cooking (campfire + stove, basic recipes)
- [ ] Food spoilage timer
- [ ] Skill system (Lumberjacking + Fishing leveling)
- [ ] Inventory screen UI

### Phase 3 — The Town & Long-term
- [ ] Town scene (general store, notice board, basic NPCs)
- [ ] Trading (sell fish/pelts/firewood for money)
- [ ] Town familiarity / hermit tracking
- [ ] Hunting (tracking, trapping, rifle, butchering)
- [ ] Animal population + seasonal behaviour
- [ ] Path wear/overgrowth system
- [ ] Peg marker system
- [ ] Ice fishing (winter)
- [ ] Journal (auto-entries, diegetic UI mode)
- [ ] Crafting screen UI
- [ ] Character appearance (hair/beard growth, dirt)

### Phase 4 — Pets, Projects, Personality
- [ ] Dog companion (retrieve, morale, feeding, vet)
- [ ] Wildlife acclimatisation system
- [ ] Car project (discoverable, multi-stage repair, Mechanics skill)
- [ ] Bicycle parts system
- [ ] Canoe crafting
- [ ] Helipad clearing + delivery system
- [ ] Hide crafting → winter clothing
- [ ] Smokehouse + food preservation
- [ ] Taxidermy skill + bench
- [ ] In-game camera + photo mode
- [ ] Generational death / legacy world
- [ ] Phone messages (ex-partner, kids)
- [ ] Environmental storytelling set-dressing spawner

### Phase 5 — Polish & Ship
- [ ] Complete audio suite (all music + SFX)
- [ ] Full animated sprite set (all 8-direction × action)
- [ ] Snow accumulation layer (winter builds up, spring melts)
- [ ] Seasonal competition event (town fair, jam/pumpkin)
- [ ] Multiple save slots (3)
- [ ] Settings screen (keybinds, audio, display, immersion toggles, difficulty)
- [ ] Main menu with mood art
- [ ] Photo printing + wall display
- [ ] Museum donation system
- [ ] All difficulty modes wired up
- [ ] Linux / macOS / Windows export builds
- [ ] Balance pass (drain rates, prices, build times)
- [ ] Bugfix pass

### Post-launch (v2.0)
- [ ] Async multiplayer: geocaching + notes
- [ ] Town DLC: buy a plot, do house-flipper renovation
- [ ] Odd jobs in town expansion

---

## Summary: Why These Design Choices?

| Design Choice | Reason from Pitch |
|--------------|------------------|
| No land purchase required | *"I think even though it's not realistic, in this game you just go out and build"* |
| Long-term projects as primary loop | *"These big long-term projects are the main thing — that's the most satisfying part"* |
| Diegetic UI default | *"I prefer it to be really diegetic... it improves immersion tenfold"* |
| No hard story | *"It's gonna be one of those games where you kind of make your own story"* |
| Winter is optional hard mode | *"Winter itself would be like the hard mode — risk/reward"* |
| Everything is optional, nothing is mandatory | *"There's always something to do — but you never have to do anything"* |
| Character looks like what you've done | *"Your character will constantly be evolving as to what you're doing"* |
| Subtle async only | *"I feel like the point of the game is that you're alone"* |
