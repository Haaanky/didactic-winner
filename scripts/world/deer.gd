class_name Deer
extends CharacterBody2D

## A wandering deer. Flees from the player when close.
## Interact with a hunting knife equipped to harvest raw meat.

signal deer_harvested(position: Vector2)

const RAW_MEAT_ID: StringName = &"raw_meat"
const MEAT_WEIGHT: float = 0.7
const MEAT_MIN: int = 1
const MEAT_MAX: int = 3
const WALK_SPEED: float = 55.0
const FLEE_SPEED: float = 140.0
const WANDER_RADIUS: float = 280.0
const FLEE_RADIUS: float = 180.0
const STOP_FLEE_RADIUS: float = 300.0
const XP_PER_HUNT: float = 20.0
const DEAD_MODULATE: Color = Color(0.5, 0.35, 0.25, 0.85)
const DEAD_ROTATION: float = 1.5

enum DeerState { IDLE, WANDERING, FLEEING, DEAD }

@export var deer_sprite: Sprite2D
@export var interact_area: Area2D

var deer_state: DeerState = DeerState.IDLE
var _home_position: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_home_position = global_position
	_target_position = global_position
	_wander_timer = _rng.randf_range(1.5, 5.0)
	add_to_group("deer")


func _physics_process(_delta: float) -> void:
	if deer_state == DeerState.DEAD:
		velocity = Vector2.ZERO
		return
	var player: PlayerController = _find_nearby_player()
	if deer_state != DeerState.FLEEING and player != null:
		var dist: float = global_position.distance_to(player.global_position)
		if dist < FLEE_RADIUS:
			deer_state = DeerState.FLEEING
	match deer_state:
		DeerState.IDLE, DeerState.WANDERING:
			_do_wander(_delta)
		DeerState.FLEEING:
			_do_flee(player)
	move_and_slide()


func interact(player: PlayerController) -> void:
	if deer_state == DeerState.DEAD:
		EventBus.journal_entry_added.emit("Already harvested.")
		return
	if player.inventory == null or not player.inventory.has_item("hunting_knife"):
		EventBus.journal_entry_added.emit(
			"You need a hunting knife to harvest the deer. Craft one: 1 log + 2 stones [I]."
		)
		return
	_harvest(player)


func get_interact_prompt(player: PlayerController) -> String:
	if deer_state == DeerState.DEAD:
		return "Deer (harvested)"
	if player.inventory == null or not player.inventory.has_item("hunting_knife"):
		return "Need hunting knife"
	return "[E] Harvest Deer"


func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		deer_state = DeerState.WANDERING
		_wander_timer = _rng.randf_range(3.0, 9.0)
		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(40.0, WANDER_RADIUS)
		_target_position = _home_position + Vector2(cos(angle), sin(angle)) * dist
	var move_vec: Vector2 = _target_position - global_position
	if move_vec.length() < 10.0:
		deer_state = DeerState.IDLE
		velocity = Vector2.ZERO
		return
	velocity = move_vec.normalized() * WALK_SPEED
	if deer_sprite != null:
		deer_sprite.flip_h = velocity.x < 0.0


func _do_flee(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		deer_state = DeerState.IDLE
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist > STOP_FLEE_RADIUS:
		deer_state = DeerState.IDLE
		_wander_timer = 2.0
		return
	var flee_dir: Vector2 = (global_position - player.global_position).normalized()
	velocity = flee_dir * FLEE_SPEED
	if deer_sprite != null:
		deer_sprite.flip_h = velocity.x < 0.0


func _find_nearby_player() -> PlayerController:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var p: Node = players[0]
	if not (p is PlayerController):
		return null
	return p as PlayerController


func _harvest(player: PlayerController) -> void:
	deer_state = DeerState.DEAD
	velocity = Vector2.ZERO
	var skill_level: int = 0
	if player.skills != null:
		skill_level = player.skills.get_level(SkillComponent.Skill.HUNTING)
		player.skills.add_xp(SkillComponent.Skill.HUNTING, XP_PER_HUNT)
	var yield_count: int = MEAT_MIN + _rng.randi_range(0, MEAT_MAX - MEAT_MIN)
	yield_count += skill_level / 3
	if player.inventory != null:
		player.inventory.add_item(RAW_MEAT_ID, yield_count, MEAT_WEIGHT)
	EventBus.journal_entry_added.emit(
		"Harvested %d raw meat from the deer. Cook it at the campfire [E near fire]." % yield_count
	)
	deer_harvested.emit(global_position)
	if deer_sprite != null:
		deer_sprite.modulate = DEAD_MODULATE
		deer_sprite.rotation = DEAD_ROTATION
