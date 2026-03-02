class_name PlayerController
extends CharacterBody2D

## Main player controller. Handles 8-directional movement, stamina, health, and interaction.
## Needs, inventory, and skill progression are delegated to child components.

signal health_changed(new_health: float)
signal interacted_with(target: Node)
signal player_died()

const MOVE_SPEED: float = 120.0
const RUN_SPEED: float = 200.0
const MAX_HEALTH: float = 100.0
const INTERACT_REACH: float = 32.0
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_PER_SECOND: float = 20.0
const STAMINA_REGEN_PER_SECOND: float = 10.0
const ENCUMBRANCE_SPEED_PENALTY: float = 0.4

@export var sprint_multiplier: float = 1.6
@export var needs: NeedsComponent
@export var inventory: InventoryComponent
@export var skills: SkillComponent
@export var appearance: AppearanceComponent
@export var sprite: AnimatedSprite2D
@export var footstep_player: AudioStreamPlayer2D

var health: float = MAX_HEALTH
var stamina: float = STAMINA_MAX
var _is_alive: bool = true
var _is_running: bool = false
var _last_direction: Vector2 = Vector2.DOWN
var _footstep_timer: float = 0.0

@onready var interact_ray: RayCast2D = $InteractRay
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	SaveManager.register_player(self)
	GameManager.set_state(GameManager.GameState.PLAYING)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	_handle_movement(delta)
	_handle_stamina(delta)
	move_and_slide()
	_handle_footsteps(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_alive:
		return
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("check_needs"):
		EventBus.ui_screen_opened.emit("needs_hud")
	elif event.is_action_pressed("pause"):
		var is_paused: bool = GameManager.current_state == GameManager.GameState.PAUSED
		EventBus.game_paused.emit(not is_paused)


func take_damage(amount: float) -> void:
	if not _is_alive:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	EventBus.player_health_changed.emit(health)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if not _is_alive:
		return
	health = minf(MAX_HEALTH, health + amount)
	health_changed.emit(health)
	EventBus.player_health_changed.emit(health)


func serialise() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y},
		"health": health,
		"stamina": stamina,
		"needs": needs.serialise() if needs != null else {},
		"inventory": inventory.serialise() if inventory != null else {},
		"skills": skills.serialise() if skills != null else {},
		"appearance": appearance.serialise() if appearance != null else {},
	}


func deserialise(data: Dictionary) -> void:
	var pos: Dictionary = data.get("position", {"x": 0.0, "y": 0.0})
	global_position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	health = data.get("health", MAX_HEALTH)
	stamina = data.get("stamina", STAMINA_MAX)
	if needs != null:
		needs.deserialise(data.get("needs", {}))
	if inventory != null:
		inventory.deserialise(data.get("inventory", {}))
	if skills != null:
		skills.deserialise(data.get("skills", {}))
	if appearance != null:
		appearance.deserialise(data.get("appearance", {}))


func _handle_movement(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		_play_idle_animation()
		return
	_last_direction = direction
	interact_ray.target_position = direction.normalized() * INTERACT_REACH
	var speed: float = _calculate_speed()
	velocity = direction * speed
	_play_walk_animation(direction)


func _handle_stamina(delta: float) -> void:
	if velocity != Vector2.ZERO and _is_running:
		stamina = maxf(stamina - STAMINA_DRAIN_PER_SECOND * delta, 0.0)
		if stamina <= 0.0:
			_is_running = false
	elif velocity == Vector2.ZERO:
		stamina = minf(stamina + STAMINA_REGEN_PER_SECOND * delta, STAMINA_MAX)


func _handle_footsteps(delta: float) -> void:
	if velocity == Vector2.ZERO:
		_footstep_timer = 0.0
		return
	var interval: float = 0.45 if not _is_running else 0.3
	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		_play_footstep()


func _calculate_speed() -> float:
	var encumbrance_ratio: float = 0.0
	if inventory != null:
		encumbrance_ratio = inventory.get_weight_ratio()
	var base: float = RUN_SPEED * sprint_multiplier if _is_running else MOVE_SPEED
	return base * (1.0 - encumbrance_ratio * ENCUMBRANCE_SPEED_PENALTY)


func _try_interact() -> void:
	if interact_ray.is_colliding():
		var target: Object = interact_ray.get_collider()
		if target is Node:
			interacted_with.emit(target as Node)
			EventBus.interaction_triggered.emit(target as Node)


func _play_walk_animation(direction: Vector2) -> void:
	if sprite == null:
		return
	var animation: StringName
	if abs(direction.x) > abs(direction.y):
		animation = &"walk_side"
		sprite.flip_h = direction.x < 0.0
	elif direction.y < 0.0:
		animation = &"walk_up"
	else:
		animation = &"walk_down"
	if sprite.animation != animation:
		sprite.play(animation)


func _play_idle_animation() -> void:
	if sprite == null:
		return
	var animation: StringName
	if abs(_last_direction.x) > abs(_last_direction.y):
		animation = &"idle_side"
		sprite.flip_h = _last_direction.x < 0.0
	elif _last_direction.y < 0.0:
		animation = &"idle_up"
	else:
		animation = &"idle_down"
	if sprite.animation != animation:
		sprite.play(animation)


func _play_footstep() -> void:
	if footstep_player == null:
		return
	footstep_player.play()


func _die() -> void:
	_is_alive = false
	player_died.emit()
	EventBus.player_died.emit()
