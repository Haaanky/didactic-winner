extends GutTest

## Tests for RockDeposit world object.

var _deposit: RockDeposit
var _player: PlayerController


func before_each() -> void:
	_deposit = RockDeposit.new()
	add_child(_deposit)
	_player = PlayerController.new()
	add_child(_player)
	var inv: InventoryComponent = InventoryComponent.new()
	_player.inventory = inv
	_player.add_child(inv)
	var skills: SkillComponent = SkillComponent.new()
	_player.skills = skills
	_player.add_child(skills)
	await get_tree().process_frame


func after_each() -> void:
	_player.queue_free()
	_deposit.queue_free()


func test_deposit_starts_with_stones() -> void:
	assert_true(_deposit.has_stones)


func test_interact_adds_stones_to_inventory() -> void:
	_deposit.interact(_player)
	assert_true(_player.inventory.has_item("stone"))


func test_interact_depletes_deposit() -> void:
	_deposit.interact(_player)
	assert_false(_deposit.has_stones)


func test_interact_empty_deposit_does_not_add_stones() -> void:
	_deposit.has_stones = false
	var qty_before: int = _player.inventory.get_quantity("stone")
	_deposit.interact(_player)
	assert_eq(_player.inventory.get_quantity("stone"), qty_before)


func test_stones_mined_signal_emitted() -> void:
	var signal_fired: bool = false
	_deposit.stones_mined.connect(func(_c: int) -> void: signal_fired = true)
	_deposit.interact(_player)
	assert_true(signal_fired)


func test_replenish_after_hours() -> void:
	_deposit.has_stones = false
	_deposit._hours_until_regrow = 1
	EventBus.hour_passed.emit(8)
	assert_true(_deposit.has_stones)


func test_get_interact_prompt_shows_mine_when_has_stones() -> void:
	_deposit.has_stones = true
	var prompt: String = _deposit.get_interact_prompt(_player)
	assert_string_contains(prompt, "Mine")


func test_get_interact_prompt_shows_depleted_when_empty() -> void:
	_deposit.has_stones = false
	var prompt: String = _deposit.get_interact_prompt(_player)
	assert_string_contains(prompt, "depleted")


func test_yield_is_within_expected_range() -> void:
	var got_stones: int = 0
	_deposit.stones_mined.connect(func(count: int) -> void: got_stones = count)
	_deposit.interact(_player)
	assert_gte(got_stones, RockDeposit.YIELD_MIN)
	assert_lte(got_stones, RockDeposit.YIELD_MAX + 3)
