extends GutTest

var _deer: Deer


func before_each() -> void:
	_deer = Deer.new()
	add_child(_deer)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_deer):
		_deer.queue_free()


func test_initial_state_idle() -> void:
	assert_eq(_deer.deer_state, Deer.DeerState.IDLE)


func test_initial_has_stones_false() -> void:
	# Deer starts alive, not dead
	assert_ne(_deer.deer_state, Deer.DeerState.DEAD)


func test_interact_without_knife_shows_message() -> void:
	watch_signals(EventBus)
	var inv := InventoryComponent.new()
	add_child(inv)
	var player: PlayerController = PlayerController.new()
	player.inventory = inv
	add_child(player)
	await get_tree().process_frame
	_deer.interact(player)
	assert_signal_emitted(EventBus, "journal_entry_added")
	assert_eq(_deer.deer_state, Deer.DeerState.IDLE, "State should stay IDLE without knife")
	player.queue_free()
	inv.queue_free()


func test_interact_with_knife_harvests() -> void:
	watch_signals(EventBus)
	var inv := InventoryComponent.new()
	add_child(inv)
	inv.add_item("hunting_knife", 1, 0.5)
	var player: PlayerController = PlayerController.new()
	player.inventory = inv
	add_child(player)
	await get_tree().process_frame
	watch_signals(_deer)
	_deer.interact(player)
	assert_eq(_deer.deer_state, Deer.DeerState.DEAD)
	assert_signal_emitted(_deer, "deer_harvested")
	assert_true(inv.has_item("raw_meat"), "Inventory should contain raw_meat after harvest")
	player.queue_free()
	inv.queue_free()


func test_interact_dead_deer_does_nothing_new() -> void:
	_deer.deer_state = Deer.DeerState.DEAD
	var inv := InventoryComponent.new()
	add_child(inv)
	inv.add_item("hunting_knife", 1, 0.5)
	var player: PlayerController = PlayerController.new()
	player.inventory = inv
	add_child(player)
	await get_tree().process_frame
	_deer.interact(player)
	assert_false(inv.has_item("raw_meat"), "Dead deer should not yield more meat")
	player.queue_free()
	inv.queue_free()


func test_get_prompt_without_knife() -> void:
	var inv := InventoryComponent.new()
	add_child(inv)
	var player: PlayerController = PlayerController.new()
	player.inventory = inv
	add_child(player)
	await get_tree().process_frame
	var prompt: String = _deer.get_interact_prompt(player)
	assert_true(prompt.contains("knife"), "Prompt should mention knife when player has none")
	player.queue_free()
	inv.queue_free()


func test_get_prompt_with_knife() -> void:
	var inv := InventoryComponent.new()
	add_child(inv)
	inv.add_item("hunting_knife", 1, 0.5)
	var player: PlayerController = PlayerController.new()
	player.inventory = inv
	add_child(player)
	await get_tree().process_frame
	var prompt: String = _deer.get_interact_prompt(player)
	assert_true(prompt.contains("[E]"), "Prompt should show [E] action with knife")
	player.queue_free()
	inv.queue_free()


func test_get_prompt_dead() -> void:
	_deer.deer_state = Deer.DeerState.DEAD
	var inv := InventoryComponent.new()
	add_child(inv)
	var player: PlayerController = PlayerController.new()
	player.inventory = inv
	add_child(player)
	await get_tree().process_frame
	var prompt: String = _deer.get_interact_prompt(player)
	assert_true(prompt.contains("harvested"), "Dead deer prompt should say harvested")
	player.queue_free()
	inv.queue_free()


func test_harvest_adds_raw_meat() -> void:
	var inv := InventoryComponent.new()
	add_child(inv)
	inv.add_item("hunting_knife", 1, 0.5)
	var player: PlayerController = PlayerController.new()
	player.inventory = inv
	add_child(player)
	await get_tree().process_frame
	_deer._harvest(player)
	var qty: int = inv.get_quantity("raw_meat")
	assert_gte(qty, Deer.MEAT_MIN)
	assert_lte(qty, Deer.MEAT_MAX)
	player.queue_free()
	inv.queue_free()
