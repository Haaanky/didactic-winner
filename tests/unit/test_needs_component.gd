extends GutTest

# Tests NeedsComponent survival-need logic.
# Hourly drain is triggered by emitting EventBus.hour_passed.
# Temperature response is triggered by emitting EventBus.temperature_changed.

var _needs: NeedsComponent


func before_each() -> void:
	_needs = NeedsComponent.new()
	add_child(_needs)


func after_each() -> void:
	_needs.queue_free()
	await get_tree().process_frame


# ── Initial state ─────────────────────────────────────────────────────────────

func test_initial_needs_all_at_max() -> void:
	for key: String in ["hunger", "warmth", "rest", "morale"]:
		assert_eq(_needs.needs[key], NeedsComponent.NEED_MAX)


func test_initial_health_is_max() -> void:
	assert_eq(_needs.health, NeedsComponent.NEED_MAX)


func test_initial_depleted_needs_is_empty() -> void:
	assert_eq(_needs._depleted_needs.size(), 0)


# ── restore_need ──────────────────────────────────────────────────────────────

func test_restore_need_increases_value() -> void:
	_needs.needs["hunger"] = 50.0
	_needs.restore_need("hunger", 20.0)
	assert_eq(_needs.needs["hunger"], 70.0)


func test_restore_need_caps_at_max() -> void:
	_needs.needs["hunger"] = 95.0
	_needs.restore_need("hunger", 20.0)
	assert_eq(_needs.needs["hunger"], NeedsComponent.NEED_MAX)


func test_restore_need_emits_need_changed() -> void:
	_needs.needs["hunger"] = 50.0
	watch_signals(EventBus)
	_needs.restore_need("hunger", 10.0)
	assert_signal_emitted_with_parameters(EventBus, "need_changed", ["hunger", 60.0])


func test_restore_need_removes_depleted_flag() -> void:
	_needs.needs["hunger"] = 0.0
	_needs._depleted_needs.append("hunger")
	_needs.restore_need("hunger", 10.0)
	assert_false(_needs._depleted_needs.has("hunger"))


func test_restore_need_ignores_unknown_key() -> void:
	_needs.restore_need("stamina", 50.0)
	assert_eq(_needs.needs["hunger"], NeedsComponent.NEED_MAX)


# ── restore_health ────────────────────────────────────────────────────────────

func test_restore_health_increases_value() -> void:
	_needs.health = 60.0
	_needs.restore_health(20.0)
	assert_eq(_needs.health, 80.0)


func test_restore_health_caps_at_max() -> void:
	_needs.health = 90.0
	_needs.restore_health(50.0)
	assert_eq(_needs.health, NeedsComponent.NEED_MAX)


func test_restore_health_emits_health_changed() -> void:
	_needs.health = 50.0
	watch_signals(EventBus)
	_needs.restore_health(10.0)
	assert_signal_emitted_with_parameters(EventBus, "health_changed", [60.0])


# ── hourly drain ──────────────────────────────────────────────────────────────

func test_hour_drains_hunger() -> void:
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.needs["hunger"], NeedsComponent.NEED_MAX - NeedsComponent.BASE_DRAIN_PER_HOUR["hunger"])


func test_hour_drains_warmth() -> void:
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.needs["warmth"], NeedsComponent.NEED_MAX - NeedsComponent.BASE_DRAIN_PER_HOUR["warmth"])


func test_hour_drains_rest() -> void:
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.needs["rest"], NeedsComponent.NEED_MAX - NeedsComponent.BASE_DRAIN_PER_HOUR["rest"])


func test_hour_drains_morale() -> void:
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.needs["morale"], NeedsComponent.NEED_MAX - NeedsComponent.BASE_DRAIN_PER_HOUR["morale"])


func test_need_floors_at_zero_after_drain() -> void:
	_needs.needs["hunger"] = 1.0
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.needs["hunger"], 0.0)


func test_drain_emits_need_critical_when_crossing_threshold() -> void:
	_needs.needs["hunger"] = NeedsComponent.CRITICAL_THRESHOLD + 1.0
	watch_signals(EventBus)
	EventBus.hour_passed.emit(9)
	assert_signal_emitted_with_parameters(EventBus, "need_critical", ["hunger"])


func test_drain_emits_need_depleted_when_zeroed() -> void:
	_needs.needs["hunger"] = 1.0
	watch_signals(EventBus)
	EventBus.hour_passed.emit(9)
	assert_signal_emitted_with_parameters(EventBus, "need_depleted", ["hunger"])


func test_need_critical_not_re_emitted_after_depletion() -> void:
	_needs.needs["hunger"] = 0.0
	_needs._depleted_needs.append("hunger")
	watch_signals(EventBus)
	EventBus.hour_passed.emit(9)
	assert_signal_not_emitted(EventBus, "need_critical")


func test_need_depleted_not_re_emitted_after_depletion() -> void:
	_needs.needs["hunger"] = 0.0
	_needs._depleted_needs.append("hunger")
	watch_signals(EventBus)
	EventBus.hour_passed.emit(9)
	assert_signal_not_emitted(EventBus, "need_depleted")


# ── health drain from depleted needs ─────────────────────────────────────────

func test_health_drains_when_a_need_is_depleted() -> void:
	_needs.needs["hunger"] = 0.0
	_needs._depleted_needs.append("hunger")
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.health, NeedsComponent.NEED_MAX - NeedsComponent.HEALTH_DRAIN_PER_HOUR)


func test_health_drains_faster_with_two_depleted_needs() -> void:
	_needs.needs["hunger"] = 0.0
	_needs.needs["warmth"] = 0.0
	_needs._depleted_needs.append("hunger")
	_needs._depleted_needs.append("warmth")
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.health, NeedsComponent.NEED_MAX - NeedsComponent.HEALTH_DRAIN_PER_HOUR * 2.0)


func test_player_dies_when_health_reaches_zero() -> void:
	_needs.health = NeedsComponent.HEALTH_DRAIN_PER_HOUR
	_needs.needs["hunger"] = 0.0
	_needs._depleted_needs.append("hunger")
	watch_signals(EventBus)
	EventBus.hour_passed.emit(9)
	assert_signal_emitted(EventBus, "player_died")


func test_health_does_not_drain_without_depleted_needs() -> void:
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.health, NeedsComponent.NEED_MAX)


# ── warmth multiplier ─────────────────────────────────────────────────────────

func test_warmth_multiplier_scales_warmth_drain() -> void:
	# Call directly to avoid WeatherManager receiving hour_passed and re-emitting
	# temperature_changed (which would reset _warmth_multiplier before the drain).
	_needs.set_warmth_multiplier(2.0)
	_needs._on_hour_passed(9)
	var expected: float = NeedsComponent.NEED_MAX - NeedsComponent.BASE_DRAIN_PER_HOUR["warmth"] * 2.0
	assert_eq(_needs.needs["warmth"], expected)


# ── morale modifier ───────────────────────────────────────────────────────────

func test_morale_modifier_equal_to_drain_prevents_loss() -> void:
	_needs.add_morale_modifier(NeedsComponent.BASE_DRAIN_PER_HOUR["morale"])
	EventBus.hour_passed.emit(9)
	assert_eq(_needs.needs["morale"], NeedsComponent.NEED_MAX)


func test_morale_modifier_resets_after_each_hour() -> void:
	_needs.add_morale_modifier(NeedsComponent.BASE_DRAIN_PER_HOUR["morale"])
	EventBus.hour_passed.emit(9)
	# Next hour: modifier is gone; morale drains normally
	EventBus.hour_passed.emit(10)
	assert_eq(_needs.needs["morale"], NeedsComponent.NEED_MAX - NeedsComponent.BASE_DRAIN_PER_HOUR["morale"])


# ── temperature → warmth multiplier ──────────────────────────────────────────

func test_temperature_minus20_sets_multiplier_4() -> void:
	EventBus.temperature_changed.emit(-20.0)
	assert_eq(_needs._warmth_multiplier, 4.0)


func test_temperature_minus10_sets_multiplier_2() -> void:
	EventBus.temperature_changed.emit(-10.0)
	assert_eq(_needs._warmth_multiplier, 2.0)


func test_temperature_minus1_sets_multiplier_1_5() -> void:
	EventBus.temperature_changed.emit(-1.0)
	assert_eq(_needs._warmth_multiplier, 1.5)


func test_temperature_20_sets_multiplier_0_3() -> void:
	EventBus.temperature_changed.emit(20.0)
	assert_eq(_needs._warmth_multiplier, 0.3)


func test_temperature_8_sets_multiplier_1() -> void:
	EventBus.temperature_changed.emit(8.0)
	assert_eq(_needs._warmth_multiplier, 1.0)


# ── is_need_critical ──────────────────────────────────────────────────────────

func test_is_need_critical_true_at_threshold() -> void:
	_needs.needs["hunger"] = NeedsComponent.CRITICAL_THRESHOLD
	assert_true(_needs.is_need_critical("hunger"))


func test_is_need_critical_false_above_threshold() -> void:
	_needs.needs["hunger"] = NeedsComponent.CRITICAL_THRESHOLD + 1.0
	assert_false(_needs.is_need_critical("hunger"))


func test_is_need_critical_true_below_threshold() -> void:
	_needs.needs["hunger"] = NeedsComponent.CRITICAL_THRESHOLD - 1.0
	assert_true(_needs.is_need_critical("hunger"))


# ── serialise / deserialise ───────────────────────────────────────────────────

func test_serialise_captures_need_values() -> void:
	_needs.needs["hunger"] = 50.0
	_needs.needs["warmth"] = 30.0
	var data: Dictionary = _needs.serialise()
	assert_eq(data["needs"]["hunger"], 50.0)
	assert_eq(data["needs"]["warmth"], 30.0)


func test_serialise_captures_health() -> void:
	_needs.health = 70.0
	var data: Dictionary = _needs.serialise()
	assert_eq(data["health"], 70.0)


func test_serialise_captures_warmth_multiplier() -> void:
	_needs._warmth_multiplier = 2.0
	var data: Dictionary = _needs.serialise()
	assert_eq(data["warmth_multiplier"], 2.0)


func test_deserialise_restores_need_values() -> void:
	var data: Dictionary = {
		"needs": {"hunger": 40.0, "warmth": 60.0, "rest": 80.0, "morale": 55.0},
		"health": 75.0,
		"warmth_multiplier": 1.5,
	}
	_needs.deserialise(data)
	assert_eq(_needs.needs["hunger"], 40.0)
	assert_eq(_needs.needs["morale"], 55.0)


func test_deserialise_restores_health() -> void:
	_needs.deserialise({"needs": {}, "health": 42.0, "warmth_multiplier": 1.0})
	assert_eq(_needs.health, 42.0)


func test_deserialise_restores_warmth_multiplier() -> void:
	_needs.deserialise({"needs": {}, "health": 100.0, "warmth_multiplier": 3.0})
	assert_eq(_needs._warmth_multiplier, 3.0)
