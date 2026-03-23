class_name FishingSpot
extends Node2D

## Fishing spot at a river or lake edge.
## Player interacts to cast, then presses [E] again when the fish bites.
## Fishing skill improves yield and reduces waiting time.

signal fishing_started()
signal fish_caught_here(item_id: String)
signal fish_escaped()

enum FishState { IDLE, WAITING_FOR_BITE, BITING, COOLDOWN }

const FISH_ITEM_ID: StringName = &"raw_fish"
const FISH_WEIGHT: float = 0.4
const BITE_TIME_MIN: float = 4.0
const BITE_TIME_MAX: float = 10.0
const BITE_WINDOW: float = 2.5
const COOLDOWN_TIME: float = 3.0
const XP_PER_CATCH: float = 15.0
const _CATCH_SFX: AudioStream = preload("res://assets/audio/fish_catch.wav")

@export var water_sprite: Sprite2D
@export var fishing_area: StaticBody2D

var fish_state: FishState = FishState.IDLE
var _bite_timer: float = 0.0
var _bite_countdown: float = 0.0
var _cooldown_timer: float = 0.0
var _fishing_player: PlayerController = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	match fish_state:
		FishState.WAITING_FOR_BITE:
			_bite_timer -= delta
			if _bite_timer <= 0.0:
				_trigger_bite()
		FishState.BITING:
			_bite_countdown -= delta
			if _bite_countdown <= 0.0:
				_fish_escaped()
		FishState.COOLDOWN:
			_cooldown_timer -= delta
			if _cooldown_timer <= 0.0:
				fish_state = FishState.IDLE


func interact(player: PlayerController) -> void:
	match fish_state:
		FishState.IDLE:
			_start_fishing(player)
		FishState.BITING:
			_catch_fish(player)
		FishState.WAITING_FOR_BITE:
			EventBus.journal_entry_added.emit("Waiting for a bite… be patient.")
		FishState.COOLDOWN:
			EventBus.journal_entry_added.emit("Give it a moment before casting again.")


func get_interact_prompt(player: PlayerController) -> String:
	match fish_state:
		FishState.IDLE:
			return "[E] Cast Line"
		FishState.WAITING_FOR_BITE:
			return "Waiting for bite…"
		FishState.BITING:
			return "[E] PULL! Fish on!"
		FishState.COOLDOWN:
			return "Fishing spot (cooling)"
	return "[E] Fish"


func _start_fishing(player: PlayerController) -> void:
	_fishing_player = player
	var skill_level: int = 0
	if player.skills != null:
		skill_level = player.skills.get_level(SkillComponent.Skill.FISHING)
	var wait_range: float = maxf(BITE_TIME_MAX - skill_level * 0.5, BITE_TIME_MIN)
	_bite_timer = _rng.randf_range(BITE_TIME_MIN, wait_range)
	fish_state = FishState.WAITING_FOR_BITE
	EventBus.journal_entry_added.emit("Line cast. Wait for a bite…")
	fishing_started.emit()


func _trigger_bite() -> void:
	fish_state = FishState.BITING
	_bite_countdown = BITE_WINDOW
	EventBus.fish_bite.emit()
	EventBus.journal_entry_added.emit("Fish on! Press [E] to pull!")


func _catch_fish(player: PlayerController) -> void:
	if not is_instance_valid(player):
		_fish_escaped()
		return
	fish_state = FishState.COOLDOWN
	_cooldown_timer = COOLDOWN_TIME
	_fishing_player = null
	var skill_level: int = 0
	if player.skills != null:
		skill_level = player.skills.get_level(SkillComponent.Skill.FISHING)
		player.skills.add_xp(SkillComponent.Skill.FISHING, XP_PER_CATCH)
	var extra: int = skill_level / 3
	if player.inventory != null:
		player.inventory.add_item(FISH_ITEM_ID, 1 + extra, FISH_WEIGHT)
	AudioManager.play_sfx(_CATCH_SFX, global_position)
	EventBus.fish_caught.emit(FISH_ITEM_ID)
	EventBus.journal_entry_added.emit("Caught a fish! Cook it at the campfire [E near fire].")
	fish_caught_here.emit(FISH_ITEM_ID)


func _fish_escaped() -> void:
	fish_state = FishState.COOLDOWN
	_cooldown_timer = COOLDOWN_TIME
	_fishing_player = null
	EventBus.fish_missed.emit()
	EventBus.journal_entry_added.emit("The fish got away. Try again.")
	fish_escaped.emit()
