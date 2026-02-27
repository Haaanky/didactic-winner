# Software Requirements Specification (SRS)
## Dudes in Alaska
**Version:** 1.0
**Date:** 2026-02-27
**Status:** Draft
**Source:** Based on Sips' "Dude Sim: Alaska" pitch from the *Pitch, Please* podcast (Yogscast Games, Aug 2020)

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Overall Description](#2-overall-description)
3. [Requirements Extraction from Pitch](#3-requirements-extraction-from-pitch)
4. [Functional Requirements](#4-functional-requirements)
5. [Non-Functional Requirements](#5-non-functional-requirements)
6. [Constraints & Assumptions](#6-constraints--assumptions)
7. [Glossary](#7-glossary)

---

## 1. Introduction

### 1.1 Purpose
This document specifies the software requirements for **Dudes in Alaska** — a 2D survival simulation game inspired by Sips' "Dude Sim: Alaska" pitch. It serves as the authoritative reference for design, development, and testing.

### 1.2 Scope
**Dudes in Alaska** is a single-player desktop game built in **Godot 4** targeting Linux, macOS, and Windows. The player takes the role of a regular dude who moves to the Alaskan wilderness to live off the land. The game blends survival, simulation, and light management in a top-down 2D world.

### 1.3 Definitions
| Term | Definition |
|------|-----------|
| The Dude | The player character |
| Homestead | The player's base camp / home area |
| Season | One of four game time periods (Spring, Summer, Autumn, Winter) |
| Needs | The survival stats the player must maintain (Hunger, Warmth, Rest, Morale) |
| Bush | The Alaskan wilderness beyond the Homestead |

### 1.4 Origin of Requirements
The concept originates from the *Pitch, Please* podcast episode *"(Sips) Dude Sim: Alaska"* (Aug 9, 2020), where Sips described "the ultimate dude game" — a dude-perspective survival simulation set in the Alaskan wilderness with emphasis on:
- Living a self-sufficient life in Alaska
- Building and maintaining a log cabin in freezing conditions
- Surviving brutal winters
- Doing quintessential "dude things" (fishing, hunting, chopping wood, etc.)

---

## 2. Overall Description

### 2.1 Product Perspective
The game is a standalone desktop application. It is a new product with no external dependencies beyond the Godot 4 runtime.

### 2.2 Product Concept
> *"You're just a dude. In Alaska. Make it work."*

The player starts with minimal supplies and a plot of land in the Alaskan wilderness. The core loop is: **gather → build → survive → thrive**. The game is intentionally unhurried — there is no combat, no external threat. The challenge comes from nature itself: cold, hunger, exhaustion.

The tone is casual, humorous, and cosy — faithful to Sips' content style. Think *Stardew Valley* meets *The Long Dark*, but without the wolves.

### 2.3 User Class
- **Primary:** Casual-to-mid-core PC gamers; fans of Sips / Yogscast; fans of survival/sim hybrids
- **Age range:** 16–40

### 2.4 Operating Environment
- Platform: PC desktop (Linux, macOS, Windows)
- Engine: Godot 4 (GDScript, standard build — no Mono/.NET)
- Resolution: 1920×1080 native; scalable
- Input: Keyboard + Mouse

### 2.5 Design Constraints
- Free and open-source tools only (Godot 4 MIT license)
- No royalties, no subscription services
- 2D only (top-down perspective)
- Solo dev-friendly architecture

---

## 3. Requirements Extraction from Pitch

### 3.1 Raw Requirements from Pitch
The following requirements were extracted from the "Dude Sim: Alaska" pitch and fan community discussions:

| ID | Raw Requirement | Source |
|----|----------------|--------|
| R-01 | "The ultimate dude game" — gameplay should feel authentically like a dude's fantasy | Pitch tagline |
| R-02 | Set in the Alaskan wilderness | Pitch title |
| R-03 | Build a log cabin as core activity | Fan community confirmation |
| R-04 | Survive freezing cold winter | Fan community confirmation |
| R-05 | Chopping wood for fuel/building | Inferred from cabin-building & survival |
| R-06 | Fishing as activity | Inferred from Alaska wilderness setting |
| R-07 | Hunting as activity | Inferred from Alaska wilderness setting |
| R-08 | The game should not be overwhelming — "dude" pace | Sips' gaming preferences (prefers chill sims) |
| R-09 | Simulation elements — daily routines, needs management | "Sim" in "Dude Sim" |
| R-10 | Self-sufficient lifestyle fantasy | Pitch concept |

---

## 4. Functional Requirements

### 4.1 World & Environment

**FR-WE-01: Open world map**
The game world shall consist of a procedurally-seeded or hand-crafted 2D top-down map representing an Alaskan wilderness region including: forest, frozen lake/river, open tundra, mountains (impassable), and the player's homestead plot.

**FR-WE-02: Day/Night cycle**
The game shall simulate a full 24-hour cycle with dynamic lighting. Night-time lowers visibility and temperature.

**FR-WE-03: Four-season system**
The game shall cycle through four seasons with distinct properties:
- **Spring:** Moderate temperature, ice thawing, animals active, good fishing
- **Summer:** Warm, long days, abundant resources, mosquitoes (minor morale debuff)
- **Autumn:** Cooling, harvest window, animal migration, preparation phase
- **Winter:** Extreme cold, snowfall, reduced daylight, survival pressure

**FR-WE-04: Weather events**
Random weather events shall occur including: blizzard (movement penalty, cold increase), heavy rain (dampness debuff), fog (visibility reduction), clear skies (morale boost).

**FR-WE-05: Temperature system**
A world temperature value shall exist, affected by season, time of day, and weather. The player's warmth stat is directly influenced by proximity to heat sources and clothing.

---

### 4.2 Player Character (The Dude)

**FR-PC-01: Movement**
The player shall move in 8 directions via keyboard (WASD or arrow keys) or controller. Movement speed is affected by encumbrance (inventory weight).

**FR-PC-02: Needs system**
The Dude shall have four survival needs, each displayed as a bar in the HUD:
| Need | Description | Consequence if empty |
|------|------------|---------------------|
| Hunger | Food intake | Health drain |
| Warmth | Body temperature | Health drain (faster in winter) |
| Rest | Sleep/fatigue | Reduced action speed, morale drop |
| Morale | Mental wellbeing | Reduced productivity, grumpy animations |

**FR-PC-03: Health**
The Dude has a health stat. It only decreases when needs are depleted. No combat health loss exists.

**FR-PC-04: Stamina**
Physical actions (chopping, carrying, running) consume stamina which regenerates when idle or resting.

**FR-PC-05: Inventory**
The Dude carries a limited-weight inventory. Items are categorised: tools, food, materials, clothing.

**FR-PC-06: Skill progression**
Repeated actions improve relevant skills:
- Lumberjacking: faster wood chopping, more yield
- Fishing: higher catch rate, rarer fish
- Hunting: quieter movement, better tracking
- Cooking: better meals, fewer ingredients wasted
- Crafting: unlocks advanced recipes

---

### 4.3 Homestead & Building

**FR-HB-01: Plot system**
The player starts with a small homestead plot. Structures can only be placed within or adjacent to the plot (expandable).

**FR-HB-02: Log cabin construction**
The player shall be able to construct a log cabin through a multi-stage process:
1. Clear land (chop trees, remove rocks)
2. Gather materials (logs, stone)
3. Lay foundation
4. Build walls
5. Add roof
6. Add door
7. Add upgrades (windows, insulation, storage shelves)

Each stage requires specific materials and tool use.

**FR-HB-03: Cabin insulation**
A built cabin reduces the effect of outdoor temperature on the Warmth stat. Better insulation = warmer interior.

**FR-HB-04: Heat sources**
Campfire (outdoor), wood stove (indoor), and fireplace can be built. Each requires fuel (wood) to operate. Fuel consumption increases in winter.

**FR-HB-05: Storage**
Chests and shelves can be crafted and placed inside the cabin to expand item storage capacity.

**FR-HB-06: Bed / sleeping area**
A sleeping mat or bed can be crafted. Sleeping restores Rest stat. Sleep at night is more effective. Sleeping outside in winter rapidly drains Warmth.

**FR-HB-07: Additional structures**
The following structures can be built beyond the cabin:
- Woodshed (covered log storage, prevents wood getting wet)
- Smokehouse (for preserving meat/fish)
- Outhouse (morale boost; optional but flavourful)
- Fishing shack (ice fishing platform over frozen lake in winter)
- Animal trap rack

---

### 4.4 Resource Gathering

**FR-RG-01: Tree felling**
Trees can be chopped with an axe. Yields logs (for building/fuel) and branches (kindling). Trees regenerate slowly over time.

**FR-RG-02: Rock mining**
Rock deposits can be mined with a pickaxe. Yields stone (building) and flint (tool-making).

**FR-RG-03: Plant foraging**
Various plants can be gathered seasonally: berries (food/morale), herbs (basic medicine), mushrooms (food).

**FR-RG-04: Snow collection**
Snow can be collected and melted for water in winter.

**FR-RG-05: Water collection**
Water can be fetched from the river/lake. Must be boiled before drinking to avoid illness debuff.

---

### 4.5 Fishing

**FR-FI-01: Summer fishing**
The player can fish from the riverbank or lakeside using a rod. A simple timing-based minigame determines success.

**FR-FI-02: Ice fishing**
In winter, the player can drill a hole in the frozen lake surface and drop a line. Different fish available in winter.

**FR-FI-03: Fish varieties**
Multiple fish types available per season with different food values and rarity.

**FR-FI-04: Fish processing**
Caught fish can be: eaten raw (minor illness risk), cooked over fire (high food value), smoked (preserved, long shelf life).

---

### 4.6 Hunting

**FR-HU-01: Animal population**
The game world shall have a population of wildlife: moose, caribou, rabbits, ptarmigan (birds). Population fluctuates seasonally.

**FR-HU-02: Trapping**
The player can craft and place small animal traps (for rabbits/birds). Traps must be checked and reset periodically.

**FR-HU-03: Tracking**
Large animals (moose/caribou) leave tracks in snow/mud. The player follows tracks to locate the animal.

**FR-HU-04: Hunting**
The player can hunt using a rifle. Hunting uses a simple aiming mechanic. Excessive noise scares animals.

**FR-HU-05: Processing game**
Hunted animals must be butchered (yields: meat, hide, fat/tallow). This takes time and must be done before the carcass spoils (temperature-dependent).

**FR-HU-06: Hides & crafting**
Animal hides can be cured and crafted into: warm clothing, sleeping bag, leather.

---

### 4.7 Cooking & Food

**FR-CO-01: Cooking methods**
Food can be cooked over: campfire, wood stove. Each method has different speed and quality.

**FR-CO-02: Recipes**
Simple recipes available from start: grilled meat, fish stew, berry jam, trail mix. More recipes unlock with Cooking skill.

**FR-CO-03: Food spoilage**
Food has a spoilage timer. Cold temperatures (winter, outdoors) slow spoilage. Smoking/drying extends shelf life significantly.

**FR-CO-04: Food quality**
Food quality affects how much Hunger it restores and provides Morale bonuses (a well-cooked meal = happy dude).

---

### 4.8 Crafting

**FR-CR-01: Crafting interface**
A crafting menu accessible from the inventory or a workbench shows available recipes and required materials.

**FR-CR-02: Tool crafting**
Basic tools craftable: hand axe, fishing rod, knife. Advanced tools require a workbench: iron axe, rifle, ice drill.

**FR-CR-03: Clothing**
Clothing crafted from hides and plant fibre. Clothing slots: head, torso, legs, feet. Each provides warmth and/or utility bonuses.

**FR-CR-04: Workbench**
A workbench structure unlocks advanced crafting recipes.

---

### 4.9 Time & Seasons

**FR-TS-01: Time progression**
In-game time progresses at a configurable rate. Default: 1 real minute = 1 in-game hour.

**FR-TS-02: Season transition**
Seasons change at fixed intervals. Transitions are gradual (3 in-game days of transition weather). Visual cues: snow accumulates, trees change colour.

**FR-TS-03: Winter preparation pressure**
The game shall provide seasonal cues encouraging winter preparation: animals visually "fattening up", leaves falling, temperature dropping. No hard deadline — the player learns from experience.

---

### 4.10 UI & HUD

**FR-UI-01: HUD**
The in-game HUD shall always show: Needs bars (Hunger, Warmth, Rest, Morale), Health indicator, current time/day/season, active tool.

**FR-UI-02: Inventory screen**
Full-screen inventory showing all carried items, weight capacity, equipped items/clothing.

**FR-UI-03: Map**
A hand-drawn-style map of the world accessible via key press. The player can mark locations.

**FR-UI-04: Journal/logbook**
A journal tracks: recipes discovered, fish caught, animals hunted, days survived. Flavour text written in Sips-style voice.

**FR-UI-05: Pause menu**
Standard pause menu: Resume, Save, Load, Settings, Quit.

---

### 4.11 Audio

**FR-AU-01: Ambient soundscape**
Ambient audio changes dynamically based on: location (forest, lake, cabin interior), time of day, season, weather.

**FR-AU-02: Action sounds**
Each action has a sound effect: chopping, fishing, footsteps on snow/grass/wood, fire crackling.

**FR-AU-03: Music**
Relaxed, atmospheric background music. Shifts tone for winter (more sparse/tense) vs summer (light and pleasant). Player can toggle.

---

### 4.12 Save System

**FR-SA-01: Manual save**
Player can save at any time from the pause menu.

**FR-SA-02: Autosave**
Game autosaves on sleep (end of day) and at season change.

**FR-SA-03: Multiple slots**
At least 3 save slots available.

---

## 5. Non-Functional Requirements

### 5.1 Performance

**NFR-PE-01:** The game shall maintain ≥60 FPS on mid-range hardware (e.g. Intel Core i5, 8GB RAM, integrated graphics or GTX 970-class GPU) at 1080p.

**NFR-PE-02:** Load times for game world shall not exceed 5 seconds on SSD hardware.

### 5.2 Usability

**NFR-US-01:** A new player shall be able to understand core mechanics within 10 minutes through in-game tooltips and a short intro sequence, with no mandatory tutorial.

**NFR-US-02:** All UI text shall be legible at 1080p without squinting. Minimum font size 14pt equivalent in-game.

**NFR-US-03:** Keyboard bindings shall be fully remappable.

### 5.3 Reliability

**NFR-RE-01:** The game shall not crash during normal gameplay. Edge cases (e.g. inventory full, extreme cold) shall be handled gracefully with player feedback.

**NFR-RE-02:** Save files shall be validated on load. Corrupt saves shall prompt the player rather than crash.

### 5.4 Maintainability

**NFR-MA-01:** All scripts shall follow the GDScript conventions in CLAUDE.md.

**NFR-MA-02:** Magic numbers shall not appear in code — all constants defined as named constants or `@export` variables.

**NFR-MA-03:** Each system (needs, crafting, building, weather, etc.) shall be a separate, self-contained script/scene.

### 5.5 Portability

**NFR-PO-01:** The game shall run without modification on Linux, macOS, and Windows using Godot 4 export templates.

---

## 6. Constraints & Assumptions

| ID | Constraint/Assumption |
|----|----------------------|
| C-01 | Budget: $0 — all tools and assets must be free/open-source |
| C-02 | Engine: Godot 4, GDScript only (no C#) |
| C-03 | Art style: 2D pixel art or hand-drawn — no 3D |
| C-04 | No online multiplayer in initial release |
| C-05 | No procedural world generation required (hand-crafted map acceptable for v1.0) |
| A-01 | Target audience is familiar with PC games and standard controls |
| A-02 | The "dude" character is not explicitly male — the name is a casual, genre reference |
| A-03 | Alaska is used as setting for aesthetic/atmosphere — not a geographical simulation |

---

## 7. Glossary

| Term | Definition |
|------|-----------|
| Needs | Survival stats: Hunger, Warmth, Rest, Morale |
| Homestead | Player's base camp / buildable plot |
| Dude | The player character (casual, everyman archetype) |
| GDScript | Godot's built-in scripting language |
| Tscn | Godot scene file format |
| TSCN | Text-based Godot scene format (version-control friendly) |
| Bush | Alaskan wilderness outside the homestead |
