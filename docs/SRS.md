# Software Requirements Specification (SRS)
## Dudes in Alaska
**Version:** 2.0
**Date:** 2026-02-27
**Status:** Draft
**Source:** Full transcript of Sips' "Dude Sim: Alaska" pitch — *Pitch, Please* podcast (Yogscast Games, Aug 9 2020)

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Overall Description](#2-overall-description)
3. [Requirements Extraction from Pitch](#3-requirements-extraction-from-pitch)
4. [Functional Requirements](#4-functional-requirements)
   - 4.17 [Touchscreen Input](#417-touchscreen-input)
   - 4.18 [Controller Input](#418-controller-input)
5. [Non-Functional Requirements](#5-non-functional-requirements)
6. [Constraints & Assumptions](#6-constraints--assumptions)
7. [Glossary](#7-glossary)

---

## 1. Introduction

### 1.1 Purpose
This document specifies the software requirements for **Dudes in Alaska**, a 2D survival simulation game based on Sips' *Dude Sim: Alaska* pitch. It is the authoritative reference for design, development, and testing. Version 2.0 supersedes v1.0 and is based on the complete podcast transcript.

### 1.2 Scope
**Dudes in Alaska** is a single-player desktop game built in **Godot 4** targeting Linux, macOS, and Windows. The player is a person who has given up on their old life and moves to the Alaskan wilderness to live self-sufficiently. The game is an open-world survival/simulation with emphasis on exploration, crafting, construction, and long-term personal projects — in a low-pressure, player-driven format.

> **Note on visual fidelity:** Sips described the game as looking like *Red Dead Redemption 2*. Our implementation is a **2D interpretation** of the same vision, built in Godot 4. The spirit — a rich, beautiful world you want to spend time in — must be preserved even in 2D.

### 1.3 Key Design Philosophy (verbatim from pitch)
> *"You're a dude. You could be a man or a woman — you're just going to be doing dude things."*
> *"There's always something to do, but you never have to do anything."*
> *"Everything you're doing is just making the game easier so you can play it quicker — that's all."*
> *"It's like inception — you have to convince them to want to do something, just subtly. You plant the seed in their head."*

### 1.4 Definitions
| Term | Definition |
|------|-----------|
| The Dude | The player character |
| The Town | The nearest small Alaskan town — the player's optional lifeline |
| Homestead | The player's chosen base area |
| Season | One of four game periods driving environment and difficulty |
| Long-term Project | A major multi-session build goal (cabin, car, helipad, etc.) |
| Diegetic UI | UI elements that exist within the game world (journal, compass, GPS device) |

---

## 2. Overall Description

### 2.1 Concept Statement
> *"Your life partner has left you, taken the kids. You've decided: 'F*** this life, I'm moving to the wilderness of Alaska.' You start with nothing — a backpack, a bit of money, a spare pair of sneakers, maybe fresh underpants. Just go."*

The game is a walking sim / survival sim hybrid. The player walks out into the wilderness, chooses a spot, and builds a life. There is no required narrative arc, no end state. The game is about the journey — making life progressively easier through work, skill, and ingenuity.

### 2.2 Tone & Feeling
- Not brutal — there is no combat, no enemies that attack
- Isolation is the challenge, not hostility
- The world should be **beautiful** — a place you want to be in
- Cosy but with real survival stakes (you can die)
- Humorous in texture: bad early taxidermy, patchwork clothing, becoming the local bigfoot legend
- References: *My Self-Reliance* YouTube channel (cited by Sips as the exact vibe)

### 2.3 User Class
- Fans of Sips / Yogscast
- Fans of chill survival sims (*Stardew Valley*, *Death Stranding*, *Red Dead 2*)
- Players who enjoy long-term projects and emergent storytelling

### 2.4 Operating Environment
- Platform: PC desktop (Linux, macOS, Windows); mobile (Android, iOS) as an optional target
- Engine: Godot 4, GDScript
- Input: Keyboard + Mouse (primary); gamepad (DS5, DS4, Xbox, Steam Controller, generic HID); touchscreen (optional, auto-detected)

---

## 3. Requirements Extraction from Pitch

### 3.1 Complete Requirement Table

All items below are directly sourced from the transcript.

| ID | Category | Requirement | Source Quote |
|----|----------|-------------|-------------|
| R-01 | Core | Player is a gender-neutral "dude" whose partner left them | *"you could be a man or a woman — you're a dude"* |
| R-02 | Core | Start with almost nothing: backpack, small money, spare clothes | *"just got like your backpack with like maybe like a little bit of money"* |
| R-03 | World | Alaskan wilderness setting, big open world | *"the wildest part of Alaska"* |
| R-04 | World | Small town accessible from wilderness — optional lifeline | *"there's a little town that you can walk to"* |
| R-05 | World | World should look beautiful — somewhere you want to spend time | *"you gotta feel like it's a world that you wanna be in"* |
| R-06 | World | Paths form naturally from repeated use, overgrow if unused | *"paths that'll form to..."* |
| R-07 | World | Player can make permanent paths using peg-and-rope markers | *"you can put down like pegs with ropes to outline a path"* |
| R-08 | World | Environmental storytelling — abandoned camps, mysterious drag marks | *"you find a camp and you notice there's like some drag marks by a tree"* |
| R-09 | Building | Log cabin built plank by plank, log by log — not prefab walls | *"it's not like in Rust where you just build a whole wall in one go... plank by plank, log by log"* |
| R-10 | Building | Structure starts with a frame/blueprint, customised from there | *"you start with a frame and a structure... then you just have to place everything onto it"* |
| R-11 | Building | Can choose size — tiny shack to large house | *"you might not want a big place... maybe just a little outhouse"* |
| R-12 | Building | Structures deteriorate very slowly with weather; wood treatment delays this | *"wouldn't wake up one morning and half your house is missing — very gradual"* |
| R-13 | Building | Build anywhere in the wilderness — no mandatory land purchase | *"I think even though it's not realistic, in this game you just go out and build"* |
| R-14 | Building | Extensions/additions can be added to existing structures at any time | *"because you might want to add extensions later"* |
| R-15 | Building | Multiple building material choices affect end appearance | *"maybe you need to replace the floor of the car — different materials change the look"* |
| R-16 | Survival | Hunger, thirst, warmth, sleep / rest needs | *"the day/night, water, hunger, thirst, do you need to sleep"* |
| R-17 | Survival | Player can die | *"yeah, I think you can die"* |
| R-18 | Survival | Health/illness: dirty water → illness, swimming with cuts → infection | *"drink dirty water... swimming with cuts all over your body you get an infection"* |
| R-19 | Survival | Bears are present in dangerous areas | *"if you want to have a bit more of a challenge there'll be bears out there"* |
| R-20 | Survival | Bears hibernate in summer — safer evenings; active other seasons | *"bears hibernate so in the summer is it safer to go out"* |
| R-21 | Death | Generational death: children can take over after player dies (up to 3 lives) | *"you know your partner left you but you have a couple of kids that could come in and take over"* |
| R-22 | Death | World is persistent — old abandoned home exists when new character starts | *"the previous house that you've built exists in the landscape... run down because it's been 10 years"* |
| R-23 | Activities | Fishing: summer rod fishing and winter ice fishing | *"you could do fishing"* |
| R-24 | Activities | Hunting with rifle (rifle bought with earned money, not starting item) | *"you might save up enough money to buy a rifle"* |
| R-25 | Activities | Trapping for smaller animals | implied by hunting/pelts system |
| R-26 | Activities | Wood chopping for firewood and building | *"you can chop wood for firewood"* |
| R-27 | Activities | Foraging: berries, fruit, vegetables, mushrooms | *"you can forage like fruit and vegetables"* |
| R-28 | Activities | Farming: grow vegetables | *"you'll have to do some farming as well"* |
| R-29 | Activities | Taxidermy: skill-based, improves over time, sellable or displayable | *"you have to skill up in it... you can do taxidermy... maybe be able to make money off it"* |
| R-30 | Activities | Photography: in-game camera, sell to town or museum | *"take pictures... sell them... become a photographer"* |
| R-31 | Activities | Cooking: produce jams, preserved food, varied meals | *"you'll be able to make jams... a pantry"* |
| R-32 | Activities | Odd jobs in town: washing dishes, manning a shop counter, etc. | *"I think it'd be really funny if you could do like odd jobs in town"* |
| R-33 | Activities | Skinning and processing hunted animals (pelts, meat, fat) | *"you could go out and do hunting... skin all of these animals"* |
| R-34 | Activities | Sewing/clothing repair and crafting patchwork outfits from found materials | *"your mechanics skill if you decide to do the car... sewing for repairs"* |
| R-35 | Vehicles | Bicycle: find parts, build it yourself (My Summer Car style) | *"you can build a bike yeah... one of the mini games will be like My Summer Car"* |
| R-36 | Vehicles | Car: find old broken car, repair piece by piece — huge long-term project | *"you find a horrible old crappy little car... recovering this vehicle"* |
| R-37 | Vehicles | Canoe: craftable by player | *"you could build a canoe"* |
| R-38 | Vehicles | 4x4 variant with trailer for cargo hauling | *"a four by four... attach a little trailer and haul more stuff"* |
| R-39 | Vehicles | Camper van variant: mobile shelter | *"the car is a camper van and you can use it as a mobile place to skip the night"* |
| R-40 | Vehicles | Helicopter / plane landing pad: clear land → deliveries arrive | *"you might have to clear a place near where you live for these deliveries"* |
| R-41 | Town | Town missions/board: NPCs request hunted game, pelts, goods | *"there's a town board in my head... oh I need a deer"* |
| R-42 | Town | Can trade: fish, pelts, firewood, surplus goods | *"you could trade stuff locally"* |
| R-43 | Town | Clothes shop in town (plaid shirts, etc.) | *"there should be like a clothes shop in town"* |
| R-44 | Town | Museum: donate items (trophies, photos, interesting finds) | *"a museum in town so you can donate stuff"* |
| R-45 | Town | Seasonal competition: biggest pumpkin, best jam, etc. | *"biggest pumpkin... who's got the best jam competition in town"* |
| R-46 | Town | Vet for pet care | *"you might need to take them into town to the vet"* |
| R-47 | Town | Town NPCs react differently based on how often you visit | *"people in town reacted to you based on how well they know you"* |
| R-48 | Town | Hermit path: if you never visit, town creates "bigfoot" rumours about you | *"you'd look like a hermit and there's all these posters of 'have you seen this person?'"* |
| R-49 | Town | Town pays more for goods in winter (supply/demand simulation) | *"the towns will pay more for stuff during the winter because they need it more"* |
| R-50 | Seasons | Four seasons with distinct visuals, temperature, animals, activities | *"you'd have really harsh winters and then really gorgeous summers — a completely different environment"* |
| R-51 | Seasons | Winter: can be optionally skipped (hibernate) if adequately prepared | *"the game sort of had some indicator to say okay you're ready for the winter... skip it, hibernate"* |
| R-52 | Seasons | Winter is effectively a hard mode with risk/reward: rare animals, higher town prices, harder deliveries | *"the only time you can hunt a certain animal is in the winter"* |
| R-53 | Seasons | Animal footprints in snow aid tracking in winter | *"in the winter it's easier to track because there's footprints in the snow"* |
| R-54 | Seasons | Winter limits building (frozen ground is harder to work) | *"building during the winter because the ground would be a lot harder"* |
| R-55 | Seasons | Option to "hibernate" over winter — game time skips to spring | *"hibernate, wake up in the spring"* |
| R-56 | Character | Beard/hair grows over time (or just hair if no beard) | *"their hair grows and their beards grow"* |
| R-57 | Character | Character gets dirty, needs to bathe | *"your character gets dirty and needs to bathe"* |
| R-58 | Character | Clothing appearance evolves: patchwork repairs, found-item rag look | *"you've made some kind of ages-old raincoat that is now a vest... mismatched but pulling it off"* |
| R-59 | Character | Hair can be styled (bun/ponytail) when long enough | *"if you have really long hair you can maybe like put in a bun or like a ponytail"* |
| R-60 | Character | Long-time players look visually distinct (rugged, dirty, patched) | *"you've been out here living for years and you just look scruffy as f*** but there's some style to it"* |
| R-61 | Pets | Dog companion: fetches hunted game, company | *"you have a dog... when he shoots something the dog goes and fetches it"* |
| R-62 | Pets | Cat companion: mouse control inside the cabin | *"maybe a cat that just lives inside... mouse problem in the house"* |
| R-63 | Pets | Wild animals become gradually more comfortable near homestead with time | *"local animals that would live near you... the longer you've been there certain animals will come closer"* |
| R-64 | Pets | Crows: feed them and they may bring back small shiny objects | *"if you give a crow some food every now and then he might come back with some jewelry that it's found"* |
| R-65 | Pets | Pets can get sick, must be taken to town vet | *"they could get sick so you might need to take them into town to the vet"* |
| R-66 | Skills | Lumberjacking skill: improved yield and speed | *"the mechanics skill if you decide to do the car"* |
| R-67 | Skills | Taxidermy skill: quality improves from creepy/bad to sellable | *"you have to skill up in it... not going to be great at first"* |
| R-68 | Skills | Mechanics skill: required for bike/car repair | *"your mechanics skill if you decide to do the car stuff or the bike"* |
| R-69 | Skills | Sewing/tailoring skill: clothing repair and crafting | *"you'll have to be able to do sewing for repairs"* |
| R-70 | Skills | Cooking skill: better recipes, less waste | implied by cooking system |
| R-71 | Skills | Carpentry: craft own furniture instead of buying | *"you should be able to just make your own furniture rather than buying"* |
| R-72 | Narrative | Partner left with kids — occasional email/text from child later | *"if you survive long enough, years in game years, you'll have an email coming through — it's like 'Dad'"* |
| R-73 | Narrative | No big conspiracy or forced story — player makes their own story | *"I want for there to be elements where when you go to town there's people you can be friends with... if you want"* |
| R-74 | Narrative | Story told through environment: abandoned campsites, unexplained drag marks | *"and you find a camp... no definitive answer but it's just nice environmental storytelling"* |
| R-75 | Narrative | One-off ranger missions (optional): go check something out, no ending | *"maybe if you're a ranger... very short little missions... it's only ever the youths in town"* |
| R-76 | Multiplayer | Subtle async multiplayer: geocaching — bury resources, appear in others' games | *"you could bury some resources and then it pops up in someone else's game"* |
| R-77 | Multiplayer | Leave notes (Death Stranding style) | *"maybe people can leave notes around"* |
| R-78 | Multiplayer | Geocaching has limits to prevent being overpowered | *"there would have to be a limit of what you can bury"* |
| R-79 | Multiplayer | Fully playable offline with no social features | *"I played through all of Death Stranding offline"* |
| R-80 | UI | Diegetic UI preferred: journal, compass, eventually GPS device | *"I prefer it to be really diegetic... making that improves the immersion tenfold"* |
| R-81 | UI | Player can choose immersion level: compass, map, or on-screen markers | *"you could choose to navigate by compass, a map, or have a marker on screen"* |
| R-82 | UI | Resource checklist when placing blueprint (like The Forest) | *"anytime you place the recipe... it has all the resources you need so you can see them tick up"* |
| R-83 | UI | GPS device: unlockable late-game, allows waypoint marking | *"later on in the game you can get a device which lets you plot waypoints"* |
| R-84 | UI | Photo mode (high quality, like Ghost of Tsushima) | *"Ghost of Tsushima's photo mode is fantastic"* |
| R-85 | Difficulty | Multiple difficulty modes: spring-forever/creative, normal, hardcore winter | *"no man's sky has five different difficulty settings... super chill mode where it's spring all the time"* |
| R-86 | Technology | Generator → electricity → laptop → emails / internet access | *"once you get a generator... you could probably get like a laptop... receive emails just to add some flavour"* |
| R-87 | Technology | Phone with very little signal — occasional pings from ex-partner/kids | *"a phone with very little signal that every now and then pings with messages from the ex"* |
| R-88 | Technology | Power tools available later (ordered via helicopter delivery) | *"save up money and then buy things that will make life easier... power tools"* |

---

## 4. Functional Requirements

### 4.1 World & Environment

**FR-WE-01: Open wilderness map**
A large 2D top-down map representing Alaskan wilderness: dense forest, river/lake, tundra, mountain borders (impassable). A small town exists at a reachable but distant position on the map.

**FR-WE-02: Dynamic path system**
The world tracks the player's movement. Repeated travel along the same route creates a visible worn path. Paths that are not used for a configurable number of in-game days slowly overgrow and disappear.

**FR-WE-03: Permanent path markers**
The player can place peg-and-rope markers along a route. Marked paths never overgrow regardless of how infrequently they are used.

**FR-WE-04: Day/Night cycle**
Full 24-hour cycle with dynamic lighting. Night reduces visibility and lowers ambient temperature.

**FR-WE-05: Four-season system**
| Season | Temp | Notable |
|--------|------|---------|
| Spring | Mild | Ice thawing, mud, animals active |
| Summer | Warm | Long days, good fishing, mosquito debuff |
| Autumn | Cool | Harvest window, animals migrating, prep phase |
| Winter | Severe | Snowfall, tracks in snow, bears active (not hibernating), buildings harder to expand |

**FR-WE-06: Weather events**
Random weather events: blizzard (movement penalty, cold surge, unfinished-structure damage risk), rain (dampness debuff), fog (visibility penalty), clear sky (morale boost).

**FR-WE-07: Environmental storytelling**
Random world set-dressing that implies a history but has no resolution: abandoned campsites with cold ash, drag marks near a tree, an old boot near a frozen lake, a rusted trap. These spawn on world generation and are purely atmospheric.

**FR-WE-08: Wildlife acclimatisation**
Wild animals (deer, foxes, birds) have a comfort radius around the homestead. The longer the player stays in the area without startling animals, the smaller the comfort radius becomes — animals approach closer over time. Hunting/running resets this progress.

---

### 4.2 Player Character

**FR-PC-01: Movement**
8-directional movement (WASD). Movement speed is reduced by: encumbrance (inventory weight), deep snow, rough terrain, fatigue.

**FR-PC-02: Four needs**
| Need | Drains from | Consequence if empty |
|------|------------|---------------------|
| Hunger | Passing time, physical exertion | Health drain |
| Warmth | Cold temperature, wet status | Health drain (faster in winter) |
| Rest | Passing time; faster when active | Speed penalty, morale drop |
| Morale | Isolation, bad meals, bad weather | Productivity penalty, grumpy idle animations |

**FR-PC-03: Health**
Health only decreases when needs are empty. No combat damage exists.

**FR-PC-04: Illness system**
Illness debuffs triggered by: drinking unboiled water, swimming with low health in cold water, being in blizzard without adequate clothing. Illness drains health and morale until treated (rest + medicine / vet).

**FR-PC-05: Stamina**
Stamina pool consumed by: chopping, running, carrying heavy loads. Regenerates at rest.

**FR-PC-06: Inventory**
Weight-based inventory. Items categorised: tools, materials, food, clothing, misc. Items stack where applicable.

**FR-PC-07: Character appearance evolution**
- Beard grows over in-game weeks (if applicable to character); hair grows over months
- Character gets visually dirtier over time; bathing resets this
- Clothing appearance degrades and can be patched with found/crafted materials
- Long hair enables styling options (bun, ponytail)
- The longer the player has survived without visiting town, the more rugged the character looks

**FR-PC-08: Phone / communication device**
Player has a phone with poor signal. Receives occasional (not constant) text messages from: the ex-partner (no response option), and eventually children (one might want to visit after enough in-game years). These messages have no gameplay consequence but provide flavour and connection.

---

### 4.3 Skills

All skills improve through repeated use (XP accumulates per action, levels at thresholds).

| Skill | Actions that level it | Bonuses at higher levels |
|-------|----------------------|-------------------------|
| Lumberjacking | Chopping trees | Speed, yield, precision felling |
| Fishing | Catching fish | Catch rate, rare fish, faster ice-drill |
| Hunting | Tracking, shooting, trapping | Quieter movement, better accuracy, more yield per animal |
| Taxidermy | Taxidermy attempts | Better quality mounts, unlocks commissions |
| Cooking | Cooking meals | Better recipes, less ingredient waste, bigger need boosts |
| Carpentry | Building structures and furniture | Speed, less material waste, more advanced plans |
| Mechanics | Repairing/building vehicles | Faster repairs, able to diagnose issues, engine tuning |
| Sewing | Repairing and crafting clothing | Better repairs, unlock advanced clothing patterns |
| Farming | Planting, tending, harvesting | Yield, pest resistance, crop variety |

Low skill = visible failure states (bad taxidermy mount, poorly fitted clothing patch, car repair attempt leaving new problems).

---

### 4.4 Construction System

**FR-CS-01: Build anywhere**
No land ownership system. The player walks into the wilderness, chooses a spot, and begins building. No grid or plot boundary is imposed.

**FR-CS-02: Blueprint-first construction**
The player places a blueprint ghost (transparent overlay). The blueprint shows required materials. Once materials are supplied to the construction site, the player manually places each element (log, plank, beam) onto the blueprint frame. Build stages are visible in real time.

**FR-CS-03: Log cabin stages**
1. Clear land (remove trees/rocks)
2. Lay foundation (stones)
3. Place wall frame (logs)
4. Fill walls (logs/planks)
5. Add roof
6. Add door
7. Finishing (window, insulation, flooring)
8. Extensions (as desired, at any time)

**FR-CS-04: Structural weathering**
Unfinished structures take slow damage from weather. Finished structures with applied wood treatment are resistant. Warning signs appear before significant damage occurs (visible cracks, discolouration). Blizzards may accelerate weathering for unfinished sections.

**FR-CS-05: Material variety affects appearance**
When the player has a choice of materials for a section (e.g. floor planks vs. birch bark vs. sheet metal scrap), the visual output differs. No material is universally "better" — it's aesthetic choice.

**FR-CS-06: Expandable homestead**
The player can add new structures at any time adjacent to the original. There is no hardcoded limit to homestead size.

**FR-CS-07: Additional structures**
| Structure | Unlocked by | Effect |
|-----------|------------|--------|
| Woodshed | Carpentry 2 | Covered log storage; prevents weather damage to fuel supply |
| Wood stove | Mechanics 1 | Indoor heat source; more efficient than open fire |
| Smokehouse | Carpentry 3 | Preserves meat/fish; extends shelf life significantly |
| Outhouse | Carpentry 1 | Morale boost |
| Fishing shack | Carpentry 2 + frozen lake | Base for ice fishing |
| Workbench | Carpentry 2 | Unlocks advanced tool/vehicle crafting |
| Taxidermy bench | Taxidermy 2 | Unlocks quality mounts and commissions |
| Pantry / cellar | Carpentry 3 | Cold food storage; slows spoilage |
| Furniture (chair, table, bed, shelves) | Carpentry (various) | Morale, storage, sleep quality |
| Helipad clearing | Late game | Enables air delivery orders |

---

### 4.5 Vehicles & Long-Term Projects

Long-term projects are the most satisfying reward loop. They are optional, take multiple sessions, and transform gameplay when complete.

**FR-VH-01: Bicycle**
Parts found in wilderness/town/ordered. Assembled at workbench using Mechanics skill. Increases travel speed significantly. Early-game vehicle.

**FR-VH-02: Car (primary long-term project)**
An old broken-down car exists somewhere in the world. Repairing it is a massive multi-stage project spanning potentially an entire season:
- Assess damage (partial list of issues revealed)
- Source parts (found, scavenged, ordered to helipad)
- Repair each system one at a time (engine, tyres, bodywork, fuel)
- Each recovered part is a small but satisfying milestone
- End result: massively expands accessible map, cargo capacity, and weather shelter
- Visual result: the car looks exactly as you repaired it — patchwork, mismatched, yours

**FR-VH-03: Canoe**
Craftable from materials (Carpentry 4). Enables river travel, opens new fishing spots, and allows crossing water bodies inaccessible on foot.

**FR-VH-04: Vehicle variants**
- 4x4 with trailer: maximum cargo, but slower
- Camper van: slower, limited cargo, but serves as mobile sleeping shelter (avoids cold death on long hunting expeditions)

**FR-VH-05: Helicopter/plane delivery**
Once the player has cleared a landing area, they can place orders (via phone/laptop) and have deliveries arrive. The player can also load up outgoing cargo for sale. First delivery arrival is a major milestone moment.

---

### 4.6 Fishing

**FR-FI-01: Summer fishing**
Rod fishing from riverbank or lakeside. Timing/skill minigame. Different species by location and season.

**FR-FI-02: Ice fishing**
In winter: drill a hole in frozen lake (requires ice drill — craftable or purchasable), lower a line, wait. Different species available. Player must manage warmth while waiting.

**FR-FI-03: Fish processing**
Raw (minor illness risk) → Cooked (good food value) → Smoked (long shelf life, sellable).

---

### 4.7 Hunting

**FR-HU-01: Animal population**
Moose, caribou, rabbit, ptarmigan, bear (dangerous). Populations are seasonal. Bears hibernate in summer (safer evenings); are active and dangerous in other seasons. Some animals are only huntable in winter.

**FR-HU-02: Tracking**
Animals leave footprints in snow/mud. Player follows tracks. Tracks degrade over time. High Hunting skill reveals more track details.

**FR-HU-03: Trapping**
Craftable small traps for rabbit/ptarmigan. Must be checked and reset periodically. Dog companion retrieves trapped game.

**FR-HU-04: Rifle**
Not a starting item. Purchased from town with saved money. Requires Hunting skill to use effectively. Loud — scares nearby animals.

**FR-HU-05: Game processing**
Hunted animals must be butchered at the kill site or homestead. Yields: meat, pelt, fat/tallow, bones. Carcass spoils faster in warm weather. Dog companion assists with retrieval.

**FR-HU-06: Hunting expeditions**
For large/distant game (bear, moose), the player may need to travel far and camp overnight. Requires tent/camper van for shelter. Game hauled back by vehicle or sled.

---

### 4.8 Crafting

**FR-CR-01: Crafting interface**
Blueprint/recipe list accessible from workbench or inventory. Required materials shown; missing materials highlighted. Resource checklist ticks up as materials are added (like The Forest).

**FR-CR-02: Pelt/hide crafting**
Animal hides can be cured (drying rack) and crafted into: warm clothing, sleeping bag, leather straps, rugs.

**FR-CR-03: Clothing system**
- Slots: head, torso, legs, feet
- Each slot has warmth value and durability
- Clothing degrades with use; repaired with Sewing skill
- Repairs use available material — visual patchwork result
- Town clothes shop sells clean/new items; crafted items have unique looks
- Character's outfit is always a visible expression of playstyle and history

**FR-CR-04: Food crafting**
Recipes include: grilled meat, fish stew, smoked fish, berry jam, trail mix, pickled vegetables, bread (farming + cooking). Quality affects need restoration and morale bonus.

**FR-CR-05: Tool crafting**
Basic tools: hand axe, fishing rod, hunting knife, fishing line, ice drill. Advanced tools: require workbench and higher Mechanics/Carpentry skill.

**FR-CR-06: Furniture crafting**
Tables, chairs, beds, shelves, storage chests — all craftable using Carpentry. Reduces need to buy from town. Each piece is placed and positioned in the home.

---

### 4.9 The Town

**FR-TW-01: Town layout**
Small town, styled like the town from *Fargo* (dialect, atmosphere). Contains: general store, clothes shop, bar/diner (odd jobs), notice board, museum, vet.

**FR-TW-02: Notice board / missions**
NPCs post requests: "I need a deer", "Can anyone bring me 10 salmon", "Need firewood". Player accepts, completes, returns for cash reward.

**FR-TW-03: Trading**
Player can sell: fish, pelts, firewood, crafted goods, taxidermy, photographs. Prices vary by season (winter = higher demand).

**FR-TW-04: Odd jobs**
Menial in-town work: washing dishes, tending shop. Pays less than wilderness activities but is available immediately without preparation. Still requires travel (up to 20 in-game km on foot initially).

**FR-TW-05: Museum**
Player can donate: trophy animals (taxidermy), photographs, interesting found objects. Donations unlock a displayed record of the player's achievements. Museum grows over time.

**FR-TW-06: Town reputation / hermit system**
NPC familiarity is tracked. Frequent visitors are greeted by name. Infrequent visitors are greeted with suspicion. If the player never visits:
- Town creates bigfoot/mystery person rumours
- Town noticeboard eventually posts "have you seen this person?"
- Arriving after years away triggers unique dialogue acknowledging the rumours
- This is entirely emergent — no forced story

**FR-TW-07: Seasonal competition**
Annual event: grow the biggest pumpkin/marrow, submit the best jam. Player can choose to participate. Win = prize money + morale boost + town fame.

---

### 4.10 Pets

**FR-PT-01: Dog**
Adoptable from town or found as stray. Benefits: retrieves hunted game and trapped animals, company (morale boost). Requires: daily feeding, vet visits when sick. Dog has own health/hunger stat.

**FR-PT-02: Cat**
Lives primarily indoors. Prevents mouse infestations in the cabin (which would damage food stores otherwise). Requires less maintenance than dog.

**FR-PT-03: Crow companion**
Not adoptable — emerges from repeated interaction. If the player leaves food in the same spot regularly, a crow begins visiting. Eventually brings back small shiny objects (buttons, coins, bottle caps). No gameplay benefit — purely flavour.

---

### 4.11 Death & Continuity

**FR-DC-01: Death conditions**
Player dies from: all needs depleted, extreme cold (exposure), illness untreated, bear attack.

**FR-DC-02: Generational continuation (optional)**
On death, the player is offered the option to continue as one of the children of the original character. Children start on the same road, make the same journey, same premise. World is persistent — the original homestead exists in the world, abandoned and decayed. Up to 3 generations.

**FR-DC-03: Legacy world**
If continuing as a new character (different run or next generation), the previous homestead exists in the landscape. It is run down: food stores spoiled, some graffiti, roof partially collapsed. Player is not required to use it, but can repair and inhabit it.

---

### 4.12 Narrative & Atmosphere

**FR-NA-01: Opening**
Player starts on a road in a small Alaskan town. Phone shows unanswered messages. Player walks out of town into the wilderness. No tutorial pop-ups — just the world.

**FR-NA-02: Emails and messages (late game)**
Once the player acquires a generator → laptop, they receive occasional emails. Content: ex-partner has moved on (flavour only), eventually one of the kids asks how things are going, mentions maybe visiting. Player cannot respond (one-way communication only).

**FR-NA-03: Environmental mystery**
Scattered throughout the world: unexplained set pieces with no resolution. The player's imagination fills the gaps. Sips' exact words: *"it might put you on edge a bit but there's nothing more to it."*

**FR-NA-04: Ranger premise (optional framing)**
The game can optionally frame the player as a newly hired wilderness ranger — given a dilapidated shack to start from, issued occasional short check-up missions. This is an optional narrative wrapper, not required gameplay.

---

### 4.13 UI & HUD

**FR-UI-01: Diegetic-first HUD**
Default HUD mode is diegetic: needs are visible by checking the phone / journal. On-screen indicators are minimal. Players can enable non-diegetic mode (bars on screen) in settings.

**FR-UI-02: Navigation options**
Player can choose between: in-world compass only, paper map (opened from inventory), or waypoint markers on screen. These are settings, not progression unlocks (except GPS device which is a late-game item).

**FR-UI-03: GPS device**
A late-game unlockable item. When carried, allows the player to mark custom waypoints on the world. Required for geocaching/async multiplayer feature.

**FR-UI-04: Resource checklist**
When a construction blueprint is placed, a list of required materials appears on screen. Each resource ticks up as it is added to the build site, providing tangible progress feedback.

**FR-UI-05: Photo mode**
High-quality photo mode accessible at any time. Adjustable camera angle, depth of field, filters. Photos taken in-game can be printed (craftable printer late-game) and hung on cabin walls, sold to town, or donated to the museum.

**FR-UI-06: Journal / logbook**
Physical journal item in inventory. Auto-logs: skills levelled, fish caught (species/size), animals hunted, buildings completed, milestones (first winter survived, first car started, etc.). Written in first-person dude voice. Serves as the primary "quest log" in diegetic form.

**FR-UI-07: Pause menu**
Resume, Save, Load, Settings (keybinds, audio, display, difficulty/immersion toggles), Quit.

---

### 4.14 Async Multiplayer (Optional Feature)

**FR-AM-01: Geocaching**
Players can bury a cache of resources at a location in their game world. The cache appears in other online players' games as a GPS ping. Finding and digging up the cache yields the buried resources.

**FR-AM-02: Cache limits**
Each player can have a maximum of 3 active buried caches at one time. Cache contents are capped at low-value resources only (wood, basic food, basic materials). Cannot bury vehicles, weapons, or large quantities.

**FR-AM-03: Notes**
Players can leave handwritten notes (text-only, moderated) at locations. Notes appear in other players' games as found scraps of paper.

**FR-AM-04: Fully offline**
All async features are disabled when playing offline. The game is fully playable without any online connectivity.

---

### 4.15 Difficulty Modes

| Mode | Description |
|------|-------------|
| Easy (Spring Forever) | No winter, no hunger drain, no illness. Just build and explore. |
| Normal | Full seasons, optional winter skip when prepared |
| Hardcore | Full seasons, winter cannot be skipped, bears are more aggressive, illness is more severe |

---

### 4.16 Save System

**FR-SA-01:** Manual save at any time from pause menu.
**FR-SA-02:** Autosave on sleep, on season change, on town visit.
**FR-SA-03:** Three save slots minimum.
**FR-SA-04:** Save includes: world state, player needs/skills/inventory, time/season, all structure positions and build stages, vehicle states, path markers, pet state, NPC familiarity values.

---

### 4.17 Touchscreen Input

**FR-TS-01: Virtual joystick**
On touchscreen devices, touching the left 45 % of the viewport spawns a floating virtual joystick centred on the initial touch point. Dragging within `JOYSTICK_RADIUS` (80 px) moves the joystick knob and drives 8-directional movement with analogue strength proportional to drag distance. Movement stops and the joystick hides when the finger lifts.

**FR-TS-02: On-screen action buttons**
Three fixed buttons are rendered in the bottom-right corner on touchscreen devices:
| Button | Label | Input Map action |
|--------|-------|-----------------|
| Interact | E | `interact` |
| Check Needs | T | `check_needs` |
| Pause | \|\| | `pause` |

Each button fires a press event on `button_down` and a release event on `button_up` via `Input.parse_input_event(InputEventAction)`, triggering the same handlers as their keyboard equivalents.

**FR-TS-03: Auto-visibility**
The `TouchController` scene calls `DisplayServer.is_touchscreen_available()` on `_ready()`. If the device reports no touchscreen, the entire controller hides and no touch-related processing runs. On desktop the touch controls are invisible; on a touchscreen device they are always visible during gameplay.

**FR-TS-04: Touch controller layer**
`TouchController` is a `CanvasLayer` at layer 10, rendered above the gameplay world and the standard HUD (layer 1) but below modal dialogs.

**FR-TS-05: Mouse-from-touch emulation**
`Project Settings → Input Devices → Pointing → Emulate Mouse From Touch` is enabled so that all standard UI controls (menus, buttons) respond correctly to finger taps without requiring special-case handling.

---

### 4.18 Controller Input

**FR-CI-01: Supported controllers**
The game supports any XInput / DirectInput / SDL2-compatible gamepad recognised by Godot 4's joypad system. Explicitly tested targets:
- Sony DualSense (PS5)
- Sony DualShock 4 (PS4)
- Xbox Series X/S controller
- Xbox One controller
- Steam Controller / Steam Deck controls
- Generic HID gamepads (Steam Input remapping)

**FR-CI-02: Analog movement**
The left analog stick drives 8-directional movement with full analogue strength (deadzone 0.5). Input Map action `move_left/right/up/down` accept `InputEventJoypadMotion` on axis 0 (horizontal) and axis 1 (vertical).

**FR-CI-03: Button mapping**
| Input Map action | Keyboard | DS5 / DS4 | Xbox | Steam Deck |
|-----------------|----------|-----------|------|------------|
| `move_left` | A / ← | L-Stick ← | L-Stick ← | L-Stick ← |
| `move_right` | D / → | L-Stick → | L-Stick → | L-Stick → |
| `move_up` | W / ↑ | L-Stick ↑ | L-Stick ↑ | L-Stick ↑ |
| `move_down` | S / ↓ | L-Stick ↓ | L-Stick ↓ | L-Stick ↓ |
| `interact` | E | Cross (✕) | A | A |
| `check_needs` | T | Triangle (△) | Y | Y |
| `open_inventory` | I | Square (□) | X | X |
| `pause` | Esc | Options | Menu | ☰ |

**FR-CI-04: Hot-plug**
Controllers can be connected or disconnected at any time without restarting the game. Godot 4's built-in joypad detection handles hot-plug automatically.

**FR-CI-05: Remapping**
All controller bindings are defined in the Godot Input Map. The pause-menu Settings screen (FR-UI-07) must include a rebinding interface for both keyboard and controller actions.

---

## 5. Non-Functional Requirements

**NFR-PE-01:** ≥60 FPS on mid-range hardware at 1080p.
**NFR-PE-02:** World load time ≤5 seconds on SSD.
**NFR-US-01:** Core mechanics learnable within 10 minutes through observation alone (no mandatory tutorial).
**NFR-US-02:** All keybindings fully remappable.
**NFR-RE-01:** No crash during normal gameplay. All edge cases handled gracefully.
**NFR-MA-01:** All scripts follow conventions in CLAUDE.md (GDScript, snake_case, signals over coupling).
**NFR-MA-02:** Each system (needs, crafting, seasons, paths, etc.) is a separate, self-contained scene/script.
**NFR-PO-01:** Runs unmodified on Linux, macOS, Windows via Godot 4 export.
**NFR-TS-01:** All core gameplay actions (movement, interact, check needs, pause) are reachable via on-screen touch controls with no keyboard required.
**NFR-TS-02:** Touch controls must not interfere with keyboard or gamepad input when multiple input devices are active simultaneously.
**NFR-CI-01:** All core gameplay actions are fully playable with a gamepad alone (no keyboard or mouse required during gameplay).
**NFR-CI-02:** Controller bindings use Godot's Input Map so they are remappable by the player without code changes.
**NFR-CI-03:** The game must not produce unhandled joypad errors or crashes when a controller is connected or disconnected mid-session.

---

## 6. Constraints & Assumptions

| ID | Statement |
|----|-----------|
| C-01 | Budget: $0 — all tools must be free/open-source |
| C-02 | Engine: Godot 4, GDScript only |
| C-03 | Visual style: 2D (Sips described 3D; our implementation adapts to 2D) |
| C-04 | No real-time online multiplayer in initial release |
| C-05 | Async multiplayer (geocaching/notes) is v2.0+ feature |
| C-06 | Mobile export (Android/iOS) is an optional v2.0+ target; v1.0 ships desktop only |
| C-07 | Known Godot 4 engine bug: `SceneTree.change_scene_to_file()` silently fails when called directly from a signal callback in exported builds. All scene transitions must use `.call_deferred()`. This is documented in `CLAUDE.md` under "Known Godot 4 Engine Pitfalls" and must be checked whenever diagnosing silent scene-change failures. |
| A-01 | "The Dude" is gender-neutral — character customisation at start |
| A-02 | Alaska is an aesthetic/atmospheric setting, not a geographic simulation |
| A-03 | The game is intentionally open-ended — there is no win state |
| A-04 | Touch controls are additive — the game remains fully playable with keyboard + mouse when no touchscreen is present |

---

## 7. Glossary

| Term | Definition |
|------|-----------|
| Dude | The player character (gender-neutral, "a way of life") |
| Homestead | Player's chosen base area in the wilderness |
| Long-term Project | Multi-session build goal: cabin, car, canoe, helipad |
| Diegetic UI | UI that exists within the game world (journal, compass, GPS device) |
| Geocaching | Async multiplayer: burying resources for other players to find |
| Hermit path | Emergent playstyle where the player avoids town entirely |
| GDScript | Godot's built-in scripting language |
