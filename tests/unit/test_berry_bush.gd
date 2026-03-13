extends GutTest

## Tests for BerryBush world object.

var _bush: BerryBush
var _player: PlayerController


func before_each() -> void:
	_bush = BerryBush.new()
	add_child(_bush)
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
	_bush.queue_free()


func test_berry_bush_starts_with_berries() -> void:
	assert_true(_bush.has_berries)


func test_interact_in_spring_adds_berries_to_inventory() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	_bush.interact(_player)
	assert_true(_player.inventory.has_item("berries"))


func test_interact_depletes_bush() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	_bush.interact(_player)
	assert_false(_bush.has_berries)


func test_interact_with_empty_bush_does_not_add_berries() -> void:
	_bush.has_berries = false
	var qty_before: int = _player.inventory.get_quantity("berries")
	_bush.interact(_player)
	assert_eq(_player.inventory.get_quantity("berries"), qty_before)


func test_interact_in_winter_does_not_add_berries() -> void:
	TimeManager.current_season = TimeManager.Season.WINTER
	_bush.interact(_player)
	assert_false(_player.inventory.has_item("berries"))
	assert_true(_bush.has_berries)


func test_get_interact_prompt_shows_pick_when_has_berries_in_spring() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	_bush.has_berries = true
	var prompt: String = _bush.get_interact_prompt(_player)
	assert_string_contains(prompt, "Pick")


func test_get_interact_prompt_shows_empty_when_no_berries() -> void:
	_bush.has_berries = false
	var prompt: String = _bush.get_interact_prompt(_player)
	assert_string_contains(prompt, "empty")


func test_hour_passed_decrements_regrow_timer() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	_bush.has_berries = false
	_bush._hours_until_regrow = 5
	EventBus.hour_passed.emit(8)
	assert_eq(_bush._hours_until_regrow, 4)


func test_regrows_when_timer_reaches_zero() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	_bush.has_berries = false
	_bush._hours_until_regrow = 1
	EventBus.hour_passed.emit(8)
	assert_true(_bush.has_berries)


func test_berry_count_is_within_expected_range() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	watch_signals(_bush)
	_bush.interact(_player)
	assert_signal_emitted(_bush, "berries_harvested")
	var args: Array = get_signal_parameters(_bush, "berries_harvested")
	assert_gte(args[0], BerryBush.BASE_YIELD_MIN)
	assert_lte(args[0], BerryBush.BASE_YIELD_MAX + 3)
