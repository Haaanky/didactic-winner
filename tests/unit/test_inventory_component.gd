extends GutTest

# Tests InventoryComponent weight-based inventory logic.

var _inv: InventoryComponent


func before_each() -> void:
	_inv = InventoryComponent.new()
	add_child(_inv)


func after_each() -> void:
	_inv.queue_free()


# ── Initial state ─────────────────────────────────────────────────────────────

func test_initial_items_is_empty() -> void:
	assert_eq(_inv.items.size(), 0)


func test_initial_total_weight_is_zero() -> void:
	assert_eq(_inv.total_weight, 0.0)


# ── add_item ──────────────────────────────────────────────────────────────────

func test_add_item_returns_true_on_success() -> void:
	assert_true(_inv.add_item("log", 1, 1.0))


func test_add_item_stores_entry() -> void:
	_inv.add_item("log", 3, 1.0)
	assert_true(_inv.items.has("log"))


func test_add_item_sets_correct_quantity() -> void:
	_inv.add_item("log", 3, 1.0)
	assert_eq(_inv.items["log"]["quantity"], 3)


func test_add_item_increments_total_weight() -> void:
	_inv.add_item("log", 4, 1.5)
	assert_eq(_inv.total_weight, 6.0)


func test_add_item_stacks_same_item() -> void:
	_inv.add_item("log", 2, 1.0)
	_inv.add_item("log", 3, 1.0)
	assert_eq(_inv.items["log"]["quantity"], 5)


func test_add_item_emits_inventory_changed() -> void:
	watch_signals(_inv)
	_inv.add_item("log", 1, 1.0)
	assert_signal_emitted(_inv, "inventory_changed")


func test_add_item_emits_item_picked_up() -> void:
	watch_signals(EventBus)
	_inv.add_item("log", 2, 1.0)
	assert_signal_emitted_with_parameters(EventBus, "item_picked_up", ["log", 2])


func test_add_item_fails_when_over_weight_limit() -> void:
	var result: bool = _inv.add_item("boulder", 1, InventoryComponent.MAX_WEIGHT + 1.0)
	assert_false(result)


func test_add_item_emits_weight_limit_reached_when_over() -> void:
	watch_signals(_inv)
	_inv.add_item("boulder", 1, InventoryComponent.MAX_WEIGHT + 1.0)
	assert_signal_emitted(_inv, "weight_limit_reached")


func test_add_item_does_not_store_item_when_over_limit() -> void:
	_inv.add_item("boulder", 1, InventoryComponent.MAX_WEIGHT + 1.0)
	assert_false(_inv.items.has("boulder"))


func test_add_item_does_not_increase_weight_when_over_limit() -> void:
	_inv.add_item("boulder", 1, InventoryComponent.MAX_WEIGHT + 1.0)
	assert_eq(_inv.total_weight, 0.0)


# ── remove_item ───────────────────────────────────────────────────────────────

func test_remove_item_returns_true_on_success() -> void:
	_inv.add_item("log", 3, 1.0)
	assert_true(_inv.remove_item("log", 1))


func test_remove_item_decreases_quantity() -> void:
	_inv.add_item("log", 3, 1.0)
	_inv.remove_item("log", 1)
	assert_eq(_inv.items["log"]["quantity"], 2)


func test_remove_item_decreases_total_weight() -> void:
	_inv.add_item("log", 3, 2.0)
	_inv.remove_item("log", 1)
	assert_eq(_inv.total_weight, 4.0)


func test_remove_item_erases_entry_at_zero_quantity() -> void:
	_inv.add_item("log", 1, 1.0)
	_inv.remove_item("log", 1)
	assert_false(_inv.items.has("log"))


func test_remove_item_returns_false_for_missing_item() -> void:
	assert_false(_inv.remove_item("sword", 1))


func test_remove_item_returns_false_when_insufficient_quantity() -> void:
	_inv.add_item("log", 1, 1.0)
	assert_false(_inv.remove_item("log", 5))


func test_remove_item_emits_inventory_changed() -> void:
	_inv.add_item("log", 2, 1.0)
	watch_signals(_inv)
	_inv.remove_item("log", 1)
	assert_signal_emitted(_inv, "inventory_changed")


func test_remove_item_emits_item_dropped() -> void:
	_inv.add_item("log", 2, 1.0)
	watch_signals(EventBus)
	_inv.remove_item("log", 1)
	assert_signal_emitted_with_parameters(EventBus, "item_dropped", ["log", 1])


# ── has_item ──────────────────────────────────────────────────────────────────

func test_has_item_returns_true_when_present() -> void:
	_inv.add_item("log", 3, 1.0)
	assert_true(_inv.has_item("log"))


func test_has_item_returns_false_when_absent() -> void:
	assert_false(_inv.has_item("log"))


func test_has_item_respects_quantity_parameter() -> void:
	_inv.add_item("log", 2, 1.0)
	assert_true(_inv.has_item("log", 2))
	assert_false(_inv.has_item("log", 3))


# ── get_quantity ──────────────────────────────────────────────────────────────

func test_get_quantity_returns_correct_count() -> void:
	_inv.add_item("log", 5, 1.0)
	assert_eq(_inv.get_quantity("log"), 5)


func test_get_quantity_returns_zero_for_missing_item() -> void:
	assert_eq(_inv.get_quantity("log"), 0)


# ── get_weight_ratio ──────────────────────────────────────────────────────────

func test_get_weight_ratio_is_zero_when_empty() -> void:
	assert_eq(_inv.get_weight_ratio(), 0.0)


func test_get_weight_ratio_is_correct_fraction() -> void:
	_inv.add_item("log", 1, InventoryComponent.MAX_WEIGHT * 0.5)
	assert_eq(_inv.get_weight_ratio(), 0.5)


func test_get_weight_ratio_is_one_at_full_capacity() -> void:
	_inv.add_item("log", 1, InventoryComponent.MAX_WEIGHT)
	assert_eq(_inv.get_weight_ratio(), 1.0)


# ── serialise / deserialise ───────────────────────────────────────────────────

func test_serialise_preserves_items() -> void:
	_inv.add_item("log", 3, 1.0)
	var data: Dictionary = _inv.serialise()
	assert_true(data["items"].has("log"))
	assert_eq(data["items"]["log"]["quantity"], 3)


func test_serialise_preserves_total_weight() -> void:
	_inv.add_item("log", 2, 1.5)
	var data: Dictionary = _inv.serialise()
	assert_eq(data["total_weight"], 3.0)


func test_deserialise_restores_items() -> void:
	var data: Dictionary = {
		"items": {"log": {"quantity": 4, "weight_per_unit": 1.0}},
		"total_weight": 4.0,
	}
	_inv.deserialise(data)
	assert_true(_inv.items.has("log"))
	assert_eq(_inv.items["log"]["quantity"], 4)


func test_deserialise_restores_total_weight() -> void:
	_inv.deserialise({"items": {}, "total_weight": 7.5})
	assert_eq(_inv.total_weight, 7.5)


func test_deserialise_emits_inventory_changed() -> void:
	watch_signals(_inv)
	_inv.deserialise({"items": {}, "total_weight": 0.0})
	assert_signal_emitted(_inv, "inventory_changed")
