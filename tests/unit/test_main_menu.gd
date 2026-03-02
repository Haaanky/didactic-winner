extends GutTest

# UI tests for MainMenu — covers every input method on every target platform.
#
# Platform coverage:
#   Desktop (Linux / Windows) — Button.pressed signal (mouse click / keyboard Enter)
#   Web (GitHub Pages)        — both signal path AND touch path (browser may emit either)
#   Mobile                    — InputEventScreenTouch through _input()
#
# Invariant: after_each() resets SceneManager._queued_scene so tests are isolated.

const MAIN_MENU_SCENE := preload("res://scenes/main.tscn")

var _menu: MainMenu


func before_each() -> void:
	_menu = MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(_menu)
	await get_tree().process_frame


func after_each() -> void:
	SceneManager._queued_scene = ""
	_menu.queue_free()


# ── Desktop / web: mouse click or keyboard Enter ──────────────────────────────

func test_play_button_pressed_signal_queues_level_01() -> void:
	_menu.play_button.pressed.emit()
	assert_eq(SceneManager._queued_scene, SceneManager.LEVEL_01_SCENE)


# ── Web / mobile: raw InputEventScreenTouch through _input() ──────────────────

func test_touch_on_play_button_queues_level_01() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _menu.play_button.get_global_rect().get_center()
	_menu._input(touch)
	assert_eq(SceneManager._queued_scene, SceneManager.LEVEL_01_SCENE)


func test_touch_release_on_play_button_does_not_queue_scene() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	touch.position = _menu.play_button.get_global_rect().get_center()
	_menu._input(touch)
	assert_eq(SceneManager._queued_scene, "")


func test_touch_outside_all_buttons_does_not_queue_scene() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2.ZERO
	_menu._input(touch)
	assert_eq(SceneManager._queued_scene, "")


# ── Non-touch events are ignored by _input() ──────────────────────────────────

func test_mouse_event_via_input_does_not_queue_scene() -> void:
	# Mouse events must go through the GUI system (Button.pressed), not _input().
	# Sending a mouse button event directly to _input() should be ignored.
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = _menu.play_button.get_global_rect().get_center()
	_menu._input(mouse)
	assert_eq(SceneManager._queued_scene, "")
