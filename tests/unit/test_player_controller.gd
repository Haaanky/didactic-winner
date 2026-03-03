extends GutTest

# Tests PlayerController health logic and signals.
# Builds a minimal scene graph (CharacterBody2D + required child nodes) to
# satisfy @onready references without needing the full player.tscn.

const DELTA := 0.1

var _player: PlayerController


func before_each() -> void:
	_player = PlayerController.new()

	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_player.add_child(collision)

	var ray := RayCast2D.new()
	ray.name = "InteractRay"
	_player.add_child(ray)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	_player.add_child(cam)

	add_child(_player)


func after_each() -> void:
	_player.queue_free()


# ── Initial state ──────────────────────────────────────────────────────────────

func test_initial_health_equals_max() -> void:
	assert_eq(_player.health, PlayerController.MAX_HEALTH)


func test_player_is_alive_on_spawn() -> void:
	assert_true(_player._is_alive)


# ── take_damage ────────────────────────────────────────────────────────────────

func test_take_damage_reduces_health() -> void:
	_player.take_damage(20.0)
	assert_eq(_player.health, 80.0)


func test_take_damage_floors_at_zero() -> void:
	_player.take_damage(999.0)
	assert_eq(_player.health, 0.0)


func test_take_damage_emits_health_changed() -> void:
	watch_signals(_player)
	_player.take_damage(25.0)
	assert_signal_emitted_with_parameters(_player, "health_changed", [75.0])


func test_take_damage_emits_eventbus_health_changed() -> void:
	watch_signals(EventBus)
	_player.take_damage(10.0)
	assert_signal_emitted_with_parameters(EventBus, "player_health_changed", [90.0])


func test_partial_damage_does_not_kill() -> void:
	_player.take_damage(PlayerController.MAX_HEALTH - 1.0)
	assert_true(_player._is_alive)


# ── heal ───────────────────────────────────────────────────────────────────────

func test_heal_increases_health() -> void:
	_player.take_damage(50.0)
	_player.heal(20.0)
	assert_eq(_player.health, 70.0)


func test_heal_caps_at_max_health() -> void:
	_player.heal(999.0)
	assert_eq(_player.health, PlayerController.MAX_HEALTH)


func test_heal_emits_health_changed() -> void:
	_player.take_damage(40.0)
	watch_signals(_player)
	_player.heal(15.0)
	assert_signal_emitted_with_parameters(_player, "health_changed", [75.0])


# ── death ──────────────────────────────────────────────────────────────────────

func test_lethal_damage_emits_player_died() -> void:
	watch_signals(_player)
	_player.take_damage(PlayerController.MAX_HEALTH)
	assert_signal_emitted(_player, "player_died")


func test_lethal_damage_emits_eventbus_player_died() -> void:
	watch_signals(EventBus)
	_player.take_damage(PlayerController.MAX_HEALTH)
	assert_signal_emitted(EventBus, "player_died")


func test_dead_player_ignores_further_damage() -> void:
	_player.take_damage(PlayerController.MAX_HEALTH)
	_player.take_damage(50.0)
	assert_eq(_player.health, 0.0)


func test_dead_player_ignores_heal() -> void:
	_player.take_damage(PlayerController.MAX_HEALTH)
	_player.heal(50.0)
	assert_eq(_player.health, 0.0)


func test_player_is_not_alive_after_lethal_damage() -> void:
	_player.take_damage(PlayerController.MAX_HEALTH)
	assert_false(_player._is_alive)


# ── constants ─────────────────────────────────────────────────────────────────

func test_max_health_is_positive() -> void:
	assert_gt(PlayerController.MAX_HEALTH, 0.0)


func test_move_speed_is_positive() -> void:
	assert_gt(PlayerController.MOVE_SPEED, 0.0)


func test_interact_reach_is_positive() -> void:
	assert_gt(PlayerController.INTERACT_REACH, 0.0)


func test_hurt_flash_duration_is_positive() -> void:
	assert_gt(PlayerController.HURT_FLASH_DURATION, 0.0)


func test_death_anim_duration_is_positive() -> void:
	assert_gt(PlayerController.DEATH_ANIM_DURATION, 0.0)


func test_run_speed_exceeds_walk_speed() -> void:
	assert_gt(PlayerController.RUN_SPEED, PlayerController.MOVE_SPEED)
