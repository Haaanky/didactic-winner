extends GutTest

# Tests NeedsComponent need tracking, drain logic, and health delegation.
# Builds a minimal scene graph (PlayerController + required child nodes + NeedsComponent)
# to satisfy @onready and get_parent() references without needing player.tscn.

const DELTA_HOUR := 1


var _player: PlayerController
var _needs: NeedsComponent


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

	_needs = NeedsComponent.new()
	_player.add_child(_needs)

	add_child(_player)
	await get_tree().process_frame


func after_each() -> void:
	_player.queue_free()


# ── Initial state ─────────────────────────────────────────────────────────────

func test_all_needs_start_at_max() -> void:
	assert_eq(_needs.needs["hunger"], NeedsComponent.NEED_MAX)
	assert_eq(_needs.needs["warmth"], NeedsComponent.NEED_MAX)
	assert_eq(_needs.needs["rest"], NeedsComponent.NEED_MAX)
	assert_eq(_needs.needs["morale"], NeedsComponent.NEED_MAX)


func test_player_controller_reference_resolved() -> void:
	assert_not_null(_needs._player_controller)


# ── restore_need ──────────────────────────────────────────────────────────────

func test_restore_need_increases_value() -> void:
	_needs.needs["hunger"] = 40.0
	_needs.restore_need("hunger", 20.0)
	assert_eq(_needs.needs["hunger"], 60.0)


func test_restore_need_caps_at_max() -> void:
	_needs.needs["hunger"] = 90.0
	_needs.restore_need("hunger", 50.0)
	assert_eq(_needs.needs["hunger"], NeedsComponent.NEED_MAX)


func test_restore_need_emits_need_changed() -> void:
	_needs.needs["warmth"] = 50.0
	watch_signals(EventBus)
	_needs.restore_need("warmth", 10.0)
	assert_signal_emitted_with_parameters(EventBus, "need_changed", ["warmth", 60.0])


func test_restore_need_invalid_key_is_ignored() -> void:
	_needs.restore_need("nonexistent", 50.0)
	assert_eq(_needs.needs["hunger"], NeedsComponent.NEED_MAX)


# ── hour drain ────────────────────────────────────────────────────────────────

func test_hour_passed_drains_hunger() -> void:
	EventBus.hour_passed.emit(DELTA_HOUR)
	assert_lt(_needs.needs["hunger"], NeedsComponent.NEED_MAX)


func test_hour_passed_drains_warmth() -> void:
	EventBus.hour_passed.emit(DELTA_HOUR)
	assert_lt(_needs.needs["warmth"], NeedsComponent.NEED_MAX)


func test_hour_passed_drains_rest() -> void:
	EventBus.hour_passed.emit(DELTA_HOUR)
	assert_lt(_needs.needs["rest"], NeedsComponent.NEED_MAX)


func test_hour_passed_drains_morale() -> void:
	EventBus.hour_passed.emit(DELTA_HOUR)
	assert_lt(_needs.needs["morale"], NeedsComponent.NEED_MAX)


func test_hunger_drain_matches_base_rate() -> void:
	EventBus.hour_passed.emit(DELTA_HOUR)
	assert_eq(_needs.needs["hunger"], NeedsComponent.NEED_MAX - NeedsComponent.BASE_DRAIN_PER_HOUR["hunger"])


# ── health delegation ─────────────────────────────────────────────────────────

func test_depleted_need_causes_player_health_drain() -> void:
	_needs.needs["hunger"] = 0.0
	_needs._depleted_needs.append("hunger")
	var health_before: float = _player.health
	EventBus.hour_passed.emit(DELTA_HOUR)
	assert_lt(_player.health, health_before)


func test_health_drain_scales_with_depleted_count() -> void:
	_needs.needs["hunger"] = 0.0
	_needs.needs["warmth"] = 0.0
	_needs._depleted_needs.append("hunger")
	_needs._depleted_needs.append("warmth")
	var health_before: float = _player.health
	EventBus.hour_passed.emit(DELTA_HOUR)
	var expected_drain: float = NeedsComponent.HEALTH_DRAIN_PER_HOUR * 2.0
	assert_eq(_player.health, maxf(health_before - expected_drain, 0.0))


# ── is_need_critical ──────────────────────────────────────────────────────────

func test_need_not_critical_at_full() -> void:
	assert_false(_needs.is_need_critical("hunger"))


func test_need_critical_at_threshold() -> void:
	_needs.needs["hunger"] = NeedsComponent.CRITICAL_THRESHOLD
	assert_true(_needs.is_need_critical("hunger"))


func test_need_critical_below_threshold() -> void:
	_needs.needs["warmth"] = NeedsComponent.CRITICAL_THRESHOLD - 1.0
	assert_true(_needs.is_need_critical("warmth"))


# ── warmth multiplier ─────────────────────────────────────────────────────────

func test_cold_temperature_increases_warmth_drain() -> void:
	# Use direct call instead of signal to avoid WeatherManager re-emitting temperature_changed.
	EventBus.temperature_changed.emit(-20.0)
	var warmth_before: float = _needs.needs["warmth"]
	_needs._on_hour_passed(DELTA_HOUR)
	var drained: float = warmth_before - _needs.needs["warmth"]
	assert_gt(drained, NeedsComponent.BASE_DRAIN_PER_HOUR["warmth"])


func test_warm_temperature_reduces_warmth_drain() -> void:
	EventBus.temperature_changed.emit(20.0)
	var warmth_before: float = _needs.needs["warmth"]
	_needs._on_hour_passed(DELTA_HOUR)
	var drained: float = warmth_before - _needs.needs["warmth"]
	assert_lt(drained, NeedsComponent.BASE_DRAIN_PER_HOUR["warmth"])


# ── serialise / deserialise ───────────────────────────────────────────────────

func test_serialise_captures_need_values() -> void:
	_needs.needs["hunger"] = 55.0
	var data: Dictionary = _needs.serialise()
	assert_eq(data["needs"]["hunger"], 55.0)


func test_deserialise_restores_need_values() -> void:
	var data: Dictionary = {"needs": {"hunger": 30.0, "warmth": 70.0, "rest": 60.0, "morale": 80.0}}
	_needs.deserialise(data)
	assert_eq(_needs.needs["hunger"], 30.0)
	assert_eq(_needs.needs["warmth"], 70.0)
