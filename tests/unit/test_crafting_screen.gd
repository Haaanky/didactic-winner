extends GutTest

## Tests for CraftingScreen UI.

const CRAFTING_SCREEN_SCENE := preload("res://scenes/ui/crafting_screen.tscn")

var _screen: CraftingScreen
var _player: PlayerController


func before_each() -> void:
	_player = PlayerController.new()
	add_child(_player)
	var inv: InventoryComponent = InventoryComponent.new()
	_player.inventory = inv
	_player.add_child(inv)
	_screen = CRAFTING_SCREEN_SCENE.instantiate() as CraftingScreen
	_screen.player = _player
	add_child(_screen)
	await get_tree().process_frame


func after_each() -> void:
	get_tree().paused = false
	_screen.queue_free()
	_player.queue_free()


func test_screen_starts_hidden() -> void:
	assert_false(_screen.visible)


func test_crafting_opened_signal_opens_screen() -> void:
	EventBus.crafting_opened.emit(false)
	assert_true(_screen.visible)
	get_tree().paused = false


func test_open_field_crafting_shows_context_label() -> void:
	_screen.open(false)
	assert_string_contains(_screen.context_label.text, "Field")
	get_tree().paused = false


func test_open_campfire_crafting_shows_campfire_context() -> void:
	_screen.open(true)
	assert_string_contains(_screen.context_label.text, "Campfire")
	get_tree().paused = false


func test_close_hides_screen() -> void:
	_screen.open(false)
	_screen._close()
	assert_false(_screen.visible)


func test_field_crafting_shows_hand_axe_recipe() -> void:
	_screen.open(false)
	var recipe_list: VBoxContainer = _screen.recipe_list
	var found_axe: bool = false
	for child: Node in recipe_list.get_children():
		if child is HBoxContainer:
			for grandchild: Node in child.get_children():
				if grandchild is VBoxContainer:
					for label: Node in grandchild.get_children():
						if label is Label and "Hand Axe" in (label as Label).text:
							found_axe = true
	assert_true(found_axe, "Hand Axe recipe should appear in field crafting")
	get_tree().paused = false


func test_campfire_crafting_shows_cooked_fish_recipe() -> void:
	_screen.open(true)
	var recipe_list: VBoxContainer = _screen.recipe_list
	var found_fish: bool = false
	for child: Node in recipe_list.get_children():
		if child is HBoxContainer:
			for grandchild: Node in child.get_children():
				if grandchild is VBoxContainer:
					for label: Node in grandchild.get_children():
						if label is Label and "Cooked Fish" in (label as Label).text:
							found_fish = true
	assert_true(found_fish, "Cooked Fish recipe should appear in campfire crafting")
	get_tree().paused = false


func test_craft_item_removes_ingredients_and_adds_output() -> void:
	_player.inventory.add_item("log", 2, 2.0)
	_player.inventory.add_item("stone", 3, 0.8)
	_screen.open(false)
	_screen._craft_item("hand_axe")
	assert_true(_player.inventory.has_item("hand_axe"))
	get_tree().paused = false


func test_touch_on_close_button_closes_screen() -> void:
	_screen.open(false)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _screen.close_button.get_global_rect().get_center()
	_screen._input(touch)
	assert_false(_screen.visible)
