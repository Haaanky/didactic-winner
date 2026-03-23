extends GutTest

const JOURNAL_SCENE := preload("res://scenes/ui/journal_screen.tscn")

var _journal: JournalScreen


func before_each() -> void:
	_journal = JOURNAL_SCENE.instantiate() as JournalScreen
	add_child(_journal)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_journal):
		_journal.queue_free()


func test_initially_hidden() -> void:
	assert_false(_journal.visible, "JournalScreen should start hidden")


func test_not_open_on_start() -> void:
	assert_false(_journal._is_open, "_is_open should be false on start")


func test_opens_via_event_bus() -> void:
	EventBus.ui_screen_opened.emit("journal")
	assert_true(_journal._is_open, "Screen should open on journal event")
	assert_true(_journal.visible, "Screen should be visible when open")
	_journal._close()


func test_ignores_other_screen_events() -> void:
	EventBus.ui_screen_opened.emit("inventory")
	assert_false(_journal._is_open, "Should not open for other screen names")


func test_journal_entry_added_accumulates() -> void:
	EventBus.journal_entry_added.emit("Entry one")
	EventBus.journal_entry_added.emit("Entry two")
	assert_eq(_journal._entries.size(), 2)


func test_max_entries_cap() -> void:
	for i: int in range(70):
		EventBus.journal_entry_added.emit("Entry %d" % i)
	assert_lte(_journal._entries.size(), JournalScreen.MAX_ENTRIES)


func test_close_hides_screen() -> void:
	_journal._open()
	_journal._close()
	assert_false(_journal.visible, "Screen should hide after close")
	assert_false(_journal._is_open)


func test_close_unpauses_tree() -> void:
	_journal._open()
	_journal._close()
	assert_false(get_tree().paused, "Tree should unpause after close")


func test_close_emits_signal() -> void:
	watch_signals(EventBus)
	_journal._open()
	_journal._close()
	assert_signal_emitted_with_parameters(EventBus, "ui_screen_closed", ["journal"])


func test_touch_on_close_button_closes() -> void:
	_journal._open()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _journal.close_button.get_global_rect().get_center()
	_journal._input(touch)
	assert_false(_journal._is_open)


func test_keyboard_open_journal_action_in_input_closes_journal() -> void:
	_journal._open()
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_J
	_journal._input(key)
	assert_false(_journal._is_open)


func test_mouse_click_on_close_button_closes_journal() -> void:
	_journal._open()
	await get_tree().process_frame
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = _journal.close_button.get_global_rect().get_center()
	_journal._input(mb)
	assert_false(_journal._is_open)


func test_keyboard_close_when_not_open_does_nothing() -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_J
	_journal._input(key)
	assert_false(_journal._is_open)
