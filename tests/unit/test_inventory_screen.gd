extends GutTest

## Tests for InventoryScreen UI.

const INVENTORY_SCREEN_SCENE := preload("res://scenes/ui/inventory_screen.tscn")

var _screen: InventoryScreen
var _player: PlayerController


func before_each() -> void:
	_player = PlayerController.new()
	add_child(_player)
	var inv: InventoryComponent = InventoryComponent.new()
	_player.inventory = inv
	_player.add_child(inv)
	var needs_comp: NeedsComponent = NeedsComponent.new()
	_player.needs = needs_comp
	_player.add_child(needs_comp)
	_screen = INVENTORY_SCREEN_SCENE.instantiate() as InventoryScreen
	_screen.player = _player
	add_child(_screen)
	await get_tree().process_frame


func after_each() -> void:
	EventBus.ui_screen_closed.emit("inventory")
	get_tree().paused = false
	_screen.queue_free()
	_player.queue_free()


func test_screen_starts_hidden() -> void:
	assert_false(_screen.visible)


func test_open_makes_screen_visible() -> void:
	_screen.open()
	assert_true(_screen.visible)
	get_tree().paused = false


func test_close_hides_screen() -> void:
	_screen.open()
	_screen._close()
	assert_false(_screen.visible)


func test_ui_screen_opened_inventory_opens_screen() -> void:
	EventBus.ui_screen_opened.emit("inventory")
	assert_true(_screen.visible)
	get_tree().paused = false


func test_screen_shows_items_from_inventory() -> void:
	_player.inventory.add_item("berries", 3, 0.1)
	_screen.open()
	var item_list: VBoxContainer = _screen.item_list
	assert_gt(item_list.get_child_count(), 0)
	get_tree().paused = false


func test_consume_food_item_removes_from_inventory() -> void:
	_player.inventory.add_item("berries", 2, 0.1)
	_screen._consume_item("berries")
	assert_eq(_player.inventory.get_quantity("berries"), 1)


func test_consume_food_item_restores_hunger() -> void:
	_player.inventory.add_item("berries", 1, 0.1)
	var initial_hunger: float = _player.needs.needs.get("hunger", 100.0)
	_player.needs.needs["hunger"] = 50.0
	_screen._consume_item("berries")
	assert_gt(_player.needs.needs.get("hunger", 0.0), 50.0)


func test_drop_item_removes_from_inventory() -> void:
	_player.inventory.add_item("log", 3, 2.0)
	_screen._drop_item("log")
	assert_eq(_player.inventory.get_quantity("log"), 2)


func test_touch_on_close_button_closes_screen() -> void:
	_screen.open()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _screen.close_button.get_global_rect().get_center()
	_screen._input(touch)
	assert_false(_screen.visible)
