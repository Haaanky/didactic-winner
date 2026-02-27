# CLAUDE.md — Dudes in Alaska

This file provides guidance for AI assistants (Claude and others) working in this repository.

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
3. **Follow naming conventions** listed above
4. **Signals over coupling** — prefer signals to direct `get_node()` calls across scene boundaries
5. **Keep scenes self-contained** — each scene should function independently where possible
6. **No magic numbers** — use named constants or `@export` variables
7. **Test in-engine** — Godot logic must be verified by running the editor; unit tests are done via `GUT` plugin if added

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
