extends GutTest

# Tests Campfire light/fuel/extinguish logic.
# Exports (flame_sprite, warmth_area, light_occluder) are left null — the
# script guards every visual access with null checks so no crashes occur.
# A stub PlayerController with an attached InventoryComponent is used for
# interact() tests.

var _campfire: Campfire
var _player: PlayerController


func _make_player() -> PlayerController:
	var player := PlayerController.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	player.add_child(collision)
	var inv := InventoryComponent.new()
	player.inventory = inv
	player.add_child(inv)
	var ray := RayCast2D.new()
	ray.name = "InteractRay"
	player.add_child(ray)
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	player.add_child(cam)
	var needs := NeedsComponent.new()
	player.needs = needs
	player.add_child(needs)
	add_child(player)
	return player


func before_each() -> void:
	_campfire = Campfire.new()
	add_child(_campfire)
	_player = _make_player()


func after_each() -> void:
	_campfire.queue_free()
	_player.queue_free()


# ── Initial state ─────────────────────────────────────────────────────────────

func test_campfire_starts_unlit() -> void:
	assert_false(_campfire.is_lit)


func test_campfire_starts_with_no_fuel() -> void:
	assert_eq(_campfire.fuel_logs, 0)


# ── add_fuel ──────────────────────────────────────────────────────────────────

func test_add_fuel_increments_fuel_logs() -> void:
	_campfire.add_fuel(3)
	assert_eq(_campfire.fuel_logs, 3)


# ── interact — lighting ───────────────────────────────────────────────────────

func test_interact_with_2_logs_lights_campfire() -> void:
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 2, 1.0)
	_campfire.interact(_player)
	assert_true(_campfire.is_lit)


func test_interact_removes_2_logs_from_inventory_on_light() -> void:
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 2, 1.0)
	_campfire.interact(_player)
	assert_false(_player.inventory.has_item(Campfire.LOG_ITEM_ID))


func test_interact_sets_fuel_to_2_on_light() -> void:
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 2, 1.0)
	_campfire.interact(_player)
	assert_eq(_campfire.fuel_logs, 2)


func test_interact_emits_lit_signal() -> void:
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 2, 1.0)
	watch_signals(_campfire)
	_campfire.interact(_player)
	assert_signal_emitted(_campfire, "lit")


func test_interact_emits_campfire_lit_on_eventbus() -> void:
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 2, 1.0)
	watch_signals(EventBus)
	_campfire.interact(_player)
	assert_signal_emitted(EventBus, "campfire_lit")


func test_interact_does_not_light_with_fewer_than_2_logs() -> void:
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 1, 1.0)
	_campfire.interact(_player)
	assert_false(_campfire.is_lit)


func test_interact_does_not_light_with_no_logs() -> void:
	_campfire.interact(_player)
	assert_false(_campfire.is_lit)


# ── interact — adding fuel ────────────────────────────────────────────────────

func test_interact_on_lit_campfire_adds_fuel() -> void:
	_campfire.is_lit = true
	_campfire.fuel_logs = 2
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 1, 1.0)
	_campfire.interact(_player)
	assert_eq(_campfire.fuel_logs, 3)


func test_interact_on_lit_removes_log_from_inventory() -> void:
	_campfire.is_lit = true
	_campfire.fuel_logs = 2
	_player.inventory.add_item(Campfire.LOG_ITEM_ID, 1, 1.0)
	_campfire.interact(_player)
	assert_false(_player.inventory.has_item(Campfire.LOG_ITEM_ID))


func test_interact_on_lit_does_not_add_fuel_without_logs() -> void:
	_campfire.is_lit = true
	_campfire.fuel_logs = 2
	_campfire.interact(_player)
	assert_eq(_campfire.fuel_logs, 2)


# ── hourly burn ───────────────────────────────────────────────────────────────

func test_hour_passed_reduces_fuel_when_lit() -> void:
	_campfire.is_lit = true
	_campfire.fuel_logs = 3
	EventBus.hour_passed.emit(9)
	assert_eq(_campfire.fuel_logs, 2)


func test_campfire_extinguishes_when_fuel_runs_out() -> void:
	_campfire.is_lit = true
	_campfire.fuel_logs = 1
	EventBus.hour_passed.emit(9)
	assert_false(_campfire.is_lit)


func test_extinguish_emits_extinguished_signal() -> void:
	_campfire.is_lit = true
	_campfire.fuel_logs = 1
	watch_signals(_campfire)
	EventBus.hour_passed.emit(9)
	assert_signal_emitted(_campfire, "extinguished")


func test_extinguish_emits_campfire_extinguished_on_eventbus() -> void:
	_campfire.is_lit = true
	_campfire.fuel_logs = 1
	watch_signals(EventBus)
	EventBus.hour_passed.emit(9)
	assert_signal_emitted(EventBus, "campfire_extinguished")


func test_hour_passed_does_nothing_when_unlit() -> void:
	_campfire.is_lit = false
	_campfire.fuel_logs = 5
	EventBus.hour_passed.emit(9)
	assert_eq(_campfire.fuel_logs, 5)


# ── body warmth area ──────────────────────────────────────────────────────────

func test_body_entered_sets_reduced_warmth_multiplier_when_lit() -> void:
	_campfire.is_lit = true
	_campfire._on_body_entered(_player)
	assert_eq(_player.needs._warmth_multiplier, Campfire.WARMTH_MULTIPLIER_NEAR_FIRE)


func test_body_entered_does_not_set_multiplier_when_unlit() -> void:
	_campfire.is_lit = false
	_campfire._on_body_entered(_player)
	assert_eq(_player.needs._warmth_multiplier, 1.0)


func test_body_exited_resets_warmth_multiplier() -> void:
	_campfire.is_lit = true
	_campfire._on_body_entered(_player)
	_campfire._on_body_exited(_player)
	assert_eq(_player.needs._warmth_multiplier, 1.0)
