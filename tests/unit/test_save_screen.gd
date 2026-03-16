extends GutTest

const SAVE_SCENE := preload("res://scenes/ui/save_screen.tscn")

var _screen: SaveScreen


func before_each() -> void:
	_screen = SAVE_SCENE.instantiate() as SaveScreen
	add_child(_screen)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	get_tree().paused = false


func test_initially_hidden() -> void:
	assert_false(_screen.visible, "SaveScreen should start hidden")


func test_not_open_on_start() -> void:
	assert_false(_screen._is_open)


func test_opens_via_event_bus() -> void:
	EventBus.ui_screen_opened.emit("save_load")
	assert_true(_screen._is_open)
	assert_true(_screen.visible)
	_screen._close()


func test_ignores_other_screens() -> void:
	EventBus.ui_screen_opened.emit("inventory")
	assert_false(_screen._is_open)


func test_close_hides() -> void:
	_screen._open()
	_screen._close()
	assert_false(_screen.visible)
	assert_false(_screen._is_open)


func test_close_unpauses_tree() -> void:
	_screen._open()
	_screen._close()
	assert_false(get_tree().paused)


func test_close_emits_signal() -> void:
	watch_signals(EventBus)
	_screen._open()
	_screen._close()
	assert_signal_emitted_with_parameters(EventBus, "ui_screen_closed", ["save_load"])


func test_open_twice_does_not_double_open() -> void:
	_screen._open()
	_screen._open()
	_screen._close()
	assert_false(_screen._is_open, "Second open call should be a no-op")


func test_slots_container_populated_on_open() -> void:
	_screen._open()
	assert_eq(_screen.slots_container.get_child_count(), SaveScreen.SLOT_COUNT)
	_screen._close()


func test_touch_on_close_button_closes() -> void:
	_screen._open()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _screen.close_button.get_global_rect().get_center()
	_screen._input(touch)
	assert_false(_screen._is_open)
