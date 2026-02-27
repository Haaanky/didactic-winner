class_name PlayerController
extends CharacterBody2D

signal health_changed(new_health: float)
signal interacted_with(target: Node)
signal player_died()

const MOVE_SPEED := 120.0
const MAX_HEALTH := 100.0
const INTERACT_REACH := 32.0

@export var sprint_multiplier: float = 1.6

var health: float = MAX_HEALTH
var _is_alive: bool = true

@onready var interact_ray: RayCast2D = $InteractRay
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)


func _physics_process(_delta: float) -> void:
	if not _is_alive:
		return
	_handle_movement()
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_alive:
		return
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("pause"):
		var is_currently_paused := GameManager.current_state == GameManager.GameState.PAUSED
		EventBus.game_paused.emit(not is_currently_paused)


func _handle_movement() -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * MOVE_SPEED
	if direction != Vector2.ZERO:
		interact_ray.target_position = direction.normalized() * INTERACT_REACH


func _try_interact() -> void:
	if interact_ray.is_colliding():
		var target := interact_ray.get_collider()
		if target is Node:
			interacted_with.emit(target as Node)
			EventBus.interaction_triggered.emit(target as Node)


func take_damage(amount: float) -> void:
	if not _is_alive:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	EventBus.player_health_changed.emit(health)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	health = minf(MAX_HEALTH, health + amount)
	health_changed.emit(health)
	EventBus.player_health_changed.emit(health)


func _die() -> void:
	_is_alive = false
	player_died.emit()
	EventBus.player_died.emit()
