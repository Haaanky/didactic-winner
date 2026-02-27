# CLAUDE.md — Dudes in Alaska

This file provides guidance for AI assistants (Claude and others) working in this repository.

---

## MANDATORY RULES — Read First, Always

> These rules apply to **every task, every file, every session** in this project. No exceptions.
> AI assistants must read and comply with all sections below before writing a single line of code.

---

### 1. Engine & Language

- **Godot 4 latest stable only** — never use Godot 3 syntax, class names, or APIs under any circumstance
- **GDScript only** — never introduce C# unless the user explicitly requests it in writing
- **Verify every API call** — if unsure whether something exists in Godot 4, check the [Godot 4 stable docs](https://docs.godotengine.org/en/stable/) before writing it
- **No deprecated APIs** — do not use methods or classes marked deprecated in Godot 4 docs
- **Static typing required** — always declare variable and return types (`:` annotations); never leave types implicit on function signatures

```gdscript
# Wrong
func take_damage(amount):
    health -= amount

# Correct
func take_damage(amount: int) -> void:
    health -= amount
```

---

### 2. Code Quality

- **Read before editing** — always read the full target file before making any change; never edit blind
- **One change at a time** — do not refactor unrelated code while implementing a feature
- **No magic numbers** — every numeric literal must be a named constant (`const`) or an `@export` variable; the only exception is `0` and `1` in arithmetic
- **No hardcoded strings for input** — always use Input Map action name strings, never raw key names like `"ui_accept"` invented on the spot
- **No print statements in final code** — use `print()` only for temporary debugging; remove before committing
- **No commented-out code** — delete unused code rather than leaving it commented out
- **Signals over coupling** — never call methods or read state across scene boundaries via `get_node()` or `$`; use signals or `@export` node references instead
- **Error handling at boundaries** — validate external data (save files, user input) but do not add defensive guards inside well-understood internal logic
- **Avoid deep nesting** — maximum 3 levels of indentation per function; extract helpers if needed
- **Functions do one thing** — each function has a single, clearly named responsibility; aim for under 30 lines

---

### 3. GDScript Type & Style Rules

- **Always use `class_name`** at the top of every script that will be referenced by other scripts
- **`@onready` for node references** — never resolve node paths in `_process` or repeated calls; cache in `@onready`
- **`await` not `yield`** — `yield` does not exist in Godot 4
- **Use `super()` not `._method()`** — Godot 4 calls parent functions with `super()` or `super.method_name()`
- **`is_instance_valid()`** before accessing potentially freed nodes — especially in async/coroutine code
- **Enums for state** — use `enum` for state machines, directions, and categories; never bare integer constants
- **No global variables in scripts** — use `@export`, signals, or autoloads for shared state

```gdscript
# Wrong
var state = 0

# Correct
enum State { IDLE, RUNNING, JUMPING, FALLING }
var state: State = State.IDLE
```

---

### 4. Scene & Node Architecture

- **Place files in the correct folder** — scripts in `scripts/`, scenes in `scenes/`, assets in `assets/`; mirror subfolders match (e.g. `scripts/player/` pairs with `scenes/characters/`)
- **One scene per entity** — player, enemy, collectible, hazard each get their own `.tscn`; do not stuff multiple unrelated entities into one scene
- **Keep scenes self-contained** — a scene must be runnable and testable in isolation (F6 in editor)
- **No hardcoded child paths in scripts** — use `@export` to reference child nodes rather than `$"Path/To/Child"`
- **Autoloads sparingly** — only `GameManager`, `AudioManager`, `SceneManager` may be autoloads; do not add more without user approval
- **Node naming: PascalCase** — node names in the scene tree must be PascalCase (`AnimatedSprite2D`, `CoyoteTimer`), not snake_case or camelCase
- **Prefer composition over inheritance** — use multiple small scenes as children rather than deep class hierarchies
- **Resources for shared data** — use `.tres` / `Resource` subclasses for shared config (enemy stats, item definitions), not duplicated constants across scripts

---

### 5. Signals & Communication

- **Declare signals at the top of the script** with typed parameters
- **Emit signals, not direct calls** — a node should never directly call a method on a node outside its own scene
- **Connect in `_ready()`** — wire up signal connections in `_ready()`, not in `_process()` or elsewhere
- **Disconnect when freeing** — if a node connects to a signal on a node it does not own, disconnect in `_exit_tree()`
- **Name signals clearly** — signals describe what happened, not what should happen (`health_changed` not `update_health`)

---

### 6. Performance

- **Never allocate in `_process` or `_physics_process`** — no `Vector2(...)`, array literals, or dictionary literals created every frame; cache them as member variables
- **Use object pooling for frequent spawns** — bullets, particles, and enemies should be pooled, not instanced/freed every time
- **Limit `get_tree().get_nodes_in_group()`** — cache results where possible; do not call in tight loops
- **Prefer `CharacterBody2D` over `RigidBody2D`** for player-controlled entities — gives precise control and avoids physics jitter
- **Use `call_deferred()` when modifying the scene tree inside a physics callback** — adding/removing nodes mid-physics step causes errors

---

### 7. Physics & Movement

- **`_physics_process` for all movement and collision** — never move physics bodies in `_process`
- **`move_and_slide()` with no arguments** — velocity is set via `self.velocity`, not passed as an argument (Godot 4)
- **Always multiply movement by `delta`** — unless using `_physics_process` with a fixed timestep that already accounts for it
- **Collision layers and masks must be set explicitly** — document which layer each entity lives on; never rely on defaults
- **Gravity via project settings** — read gravity from `ProjectSettings.get_setting("physics/2d/default_gravity")` or the physics server; do not hardcode a gravity constant

---

### 8. Input

- **All actions defined in Input Map** — never reference a raw key scancode or string not present in the Input Map
- **`_input()` for event-driven input** (jump press, interact), **`_physics_process()` for held input** (movement axis)
- **No input polling in `_ready()` or `_process()`** unless necessary — prefer `_unhandled_input()` for gameplay, `_input()` for UI
- **Support keyboard and controller** — when adding an action, map it to both a key and a gamepad button where applicable

---

### 9. Audio

- **All audio through `AudioManager` autoload** — never call `AudioStreamPlayer.play()` directly from gameplay scripts; route through the singleton
- **Use audio buses** — music on `Music` bus, SFX on `SFX` bus; allows independent volume control
- **Preload, don't load at runtime** — use `preload("res://assets/audio/jump.ogg")` at script level, not `load()` at play time

---

### 10. File & Asset Conventions

| Asset type | Folder | Format |
|---|---|---|
| Sprite sheets | `assets/sprites/` | `.png` |
| Audio | `assets/audio/` | `.ogg` (music), `.wav` (SFX) |
| Fonts | `assets/fonts/` | `.ttf` or `.otf` |
| Scenes | `scenes/<category>/` | `.tscn` |
| Scripts | `scripts/<category>/` | `.gd` |
| Resources | `resources/` | `.tres` |

- **No spaces in file or folder names** — use `snake_case` only
- **No uppercase in file names** — `player_controller.gd`, not `PlayerController.gd`

---

### 11. Git

- **Always work on a `claude/<description>-<id>` branch** — never commit directly to `main`
- **Commit messages are imperative present tense** — `Add player jump`, not `Added` or `Adding`
- **One logical change per commit** — do not bundle unrelated changes
- **Do not commit generated files** — `.godot/`, `*.import`, `export_presets.cfg`, `build/`
- **Do not commit editor layout files** — `.godot/editor/` is gitignored for a reason
- **Stage specific files** — never `git add .` blindly; always review what is staged

---

### 12. AI Behaviour

- **Read `CLAUDE.md` at the start of every session** — rules change; always use the current version
- **Read every file before editing it** — no exceptions, even for "obvious" one-line fixes
- **Ask before deviating from any rule** — if a user request conflicts with a rule above, flag it explicitly before proceeding
- **No speculative changes** — only modify what was explicitly requested; do not "improve" surrounding code
- **No unnecessary abstractions** — do not create helper functions, base classes, or utilities for single-use cases
- **Confirm destructive git operations** — never `reset --hard`, `push --force`, or delete branches without explicit user confirmation
- **Scope changes to the task** — do not rename variables, reformat files, or adjust whitespace in files not directly related to the task
- **Report blockers clearly** — if a task cannot be completed as specified (missing asset, API uncertainty, rule conflict), say so immediately rather than guessing

---

## Project Overview

**Dudes in Alaska** is a 2D game built with [Godot 4](https://godotengine.org/) — a free, open-source game engine. The project lives in this repository and targets desktop platforms (Linux, macOS, Windows).

The game engine of choice is **Godot 4** because:
- Completely free and open-source (MIT license)
- No royalties or subscription fees
- GDScript is simple and Python-like — low barrier to entry
- Godot 4 (4.x) is the current, actively maintained major version
- Excellent built-in 2D renderer and physics
- Version control friendly (text-based scene/resource files)

---

## Repository Structure

Once the Godot project is initialized, the repository will follow this layout:

```
didactic-winner/
├── CLAUDE.md               # This file
├── README.md               # Project overview
├── project.godot           # Godot project configuration
├── export_presets.cfg      # Export targets (gitignored if it contains keys)
├── assets/
│   ├── sprites/            # Character and environment sprite sheets
│   ├── audio/              # Music and sound effects
│   └── fonts/              # Bitmap/TTF fonts
├── scenes/
│   ├── main.tscn           # Entry scene
│   ├── ui/                 # HUD, menus, overlays
│   ├── levels/             # Individual level scenes
│   ├── characters/         # Player and NPC scenes
│   └── objects/            # Interactable objects, collectibles
├── scripts/
│   ├── player/             # Player controller logic
│   ├── enemies/            # Enemy AI
│   ├── ui/                 # UI logic
│   └── autoloads/          # Singleton/autoload scripts (GameManager, etc.)
└── .gitignore
```

---

## Game Engine: Godot 4

### Version Policy

**Always use the latest stable Godot 4.x release.**

- Target the latest stable `4.x` version at all times (e.g. 4.4, not 4.3 or Godot 3.x)
- AI assistants must generate code and APIs compatible with **Godot 4 latest stable** — never Godot 3 syntax
- When in doubt, cross-reference the [Godot 4 stable docs](https://docs.godotengine.org/en/stable/)
- Common Godot 3 → 4 traps to avoid:

| Godot 3 (wrong) | Godot 4 (correct) |
|-----------------|-------------------|
| `KinematicBody2D` | `CharacterBody2D` |
| `move_and_slide(velocity)` | `move_and_slide()` (velocity is a property) |
| `yield()` | `await` |
| `onready var` | `@onready var` |
| `export var` | `@export var` |
| `connect("signal", self, "_method")` | `signal.connect(_method)` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |

### Installation

Download from https://godotengine.org/download — choose **Godot 4 (Standard)**, no Mono/.NET needed unless C# is used.

No installation required — Godot is a single executable.

### Running the Project

Open Godot, click **Import**, and select the `project.godot` file in this repository.

From the Godot editor, press **F5** (or the Play button) to run the game.

### Command-line Run

```bash
godot --path /home/user/didactic-winner
```

### Export (Build)

```bash
godot --path /home/user/didactic-winner --export-release "Linux/X11" ./build/dudes-in-alaska.x86_64
```

---

## Scripting Language: GDScript

This project uses **GDScript** (not C#). GDScript is Godot's built-in scripting language — fast to write, no compilation step, and idiomatic for Godot.

### Conventions

- **File names:** `snake_case.gd` for scripts, `snake_case.tscn` for scenes
- **Class names:** `PascalCase` (e.g., `class_name PlayerController`)
- **Variables:** `snake_case`
- **Constants:** `UPPER_SNAKE_CASE`
- **Functions:** `snake_case`
- **Private members:** prefix with underscore (`_ready`, `_physics_process`, `_my_helper`)
- **Signals:** past-tense verb or noun phrase (`health_changed`, `player_died`)

### Example Script Structure

```gdscript
class_name PlayerController
extends CharacterBody2D

signal health_changed(new_health: int)

const MAX_HEALTH := 100
const MOVE_SPEED := 200.0

@export var jump_force: float = 400.0

var health: int = MAX_HEALTH

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	move_and_slide()


func _handle_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * MOVE_SPEED
```

---

## Scene Architecture

Follow Godot's **node composition** pattern — scenes are self-contained units.

- Each gameplay entity (player, enemy, item) is its own `.tscn` scene
- Scenes communicate via **signals** (not direct node references across scene boundaries)
- Use **Autoloads** (singletons) sparingly — only for truly global state: `GameManager`, `AudioManager`, `SceneManager`
- Avoid deeply coupled node paths; prefer `@export` references or signals

### Node Naming

Use `PascalCase` for node names in the scene tree:
```
PlayerController
├── AnimatedSprite2D
├── CollisionShape2D
└── CoyoteTimer (Timer node)
```

---

## Input Map

Define all inputs in **Project > Project Settings > Input Map**, not hardcoded. Reference by name:

```gdscript
Input.is_action_pressed("jump")
Input.get_axis("move_left", "move_right")
```

Standard actions to define:
- `move_left`, `move_right`, `move_up`, `move_down`
- `jump`
- `interact`
- `pause`

---

## Git Workflow

### Branches

- `main` — stable, reviewed code
- `claude/<description>-<id>` — AI-assisted feature branches
- `feature/<description>` — human-authored features

### .gitignore

Godot generates some files that should not be committed:

```
# Godot-specific
.godot/
*.import
export_presets.cfg

# Build output
build/

# OS files
.DS_Store
Thumbs.db
```

### Commits

Write clear, imperative commit messages:
```
Add player jump mechanic
Fix enemy patrol path wrapping
Add Alaska forest tileset
```

---

## Development Workflow for AI Assistants

1. **Read before editing** — always read existing scripts/scenes before modifying
2. **Use GDScript** — do not introduce C# unless explicitly requested
3. **Use Godot 4 latest stable APIs only** — never generate Godot 3 syntax; see the Version Policy table above
4. **Follow naming conventions** listed above
5. **Signals over coupling** — prefer signals to direct `get_node()` calls across scene boundaries
6. **Keep scenes self-contained** — each scene should function independently where possible
7. **No magic numbers** — use named constants or `@export` variables
8. **Test in-engine** — Godot logic must be verified by running the editor; unit tests are done via `GUT` plugin if added

---

## Future Setup Checklist

- [ ] Initialize Godot 4 project (`project.godot`)
- [ ] Configure `.gitignore` for Godot
- [ ] Set up Input Map actions
- [ ] Create main scene (`scenes/main.tscn`)
- [ ] Add `SceneManager` autoload
- [ ] Add `GameManager` autoload
- [ ] Create player scene and basic movement
- [ ] Add first level layout
