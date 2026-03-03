extends GutTest

# UI tests for ControlsOverlay — covers every input method on every target platform.
#
# Platform coverage:
#   Desktop (Linux / Windows) — InputEventMouseButton (mouse click)
#   Web (GitHub Pages)        — both mouse and touch paths
#   Mobile                    — InputEventScreenTouch through _input()
#
# Invariant: after_each() calls queue_free() only when the overlay was not
# already freed by the test itself.

const CONTROLS_OVERLAY_SCENE := preload("res://scenes/ui/controls_overlay.tscn")

var _overlay: ControlsOverlay


func before_each() -> void:
	_overlay = CONTROLS_OVERLAY_SCENE.instantiate() as ControlsOverlay
	add_child(_overlay)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()


# ── First-frame protection ────────────────────────────────────────────────────

func test_input_ignored_before_activation() -> void:
	var overlay := CONTROLS_OVERLAY_SCENE.instantiate() as ControlsOverlay
	add_child(overlay)
	# No frame wait — _accepting_input is still false
	watch_signals(overlay)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	overlay._input(event)
	assert_signal_not_emitted(overlay, "dismissed")
	overlay.queue_free()


# ── Visible on start ──────────────────────────────────────────────────────────

func test_overlay_is_visible_on_start() -> void:
	assert_true(_overlay.visible)


# ── Grid populated ────────────────────────────────────────────────────────────

func test_controls_grid_has_children_after_ready() -> void:
	assert_gt(_overlay.controls_grid.get_child_count(), 0)


# ── Desktop: mouse click dismisses ───────────────────────────────────────────

func test_mouse_left_click_emits_dismissed() -> void:
	watch_signals(_overlay)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_overlay._input(event)
	assert_signal_emitted(_overlay, "dismissed")


func test_mouse_click_frees_overlay() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_overlay._input(event)
	await get_tree().process_frame
	assert_false(is_instance_valid(_overlay))


func test_mouse_button_release_does_not_dismiss() -> void:
	watch_signals(_overlay)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	_overlay._input(event)
	assert_signal_not_emitted(_overlay, "dismissed")


# ── Web / mobile: touch tap dismisses ────────────────────────────────────────

func test_touch_press_emits_dismissed() -> void:
	watch_signals(_overlay)
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = Vector2(100.0, 100.0)
	_overlay._input(event)
	assert_signal_emitted(_overlay, "dismissed")


func test_touch_release_does_not_dismiss() -> void:
	watch_signals(_overlay)
	var event := InputEventScreenTouch.new()
	event.pressed = false
	event.position = Vector2(100.0, 100.0)
	_overlay._input(event)
	assert_signal_not_emitted(_overlay, "dismissed")


# ── Keyboard: any key press dismisses ────────────────────────────────────────

func test_key_press_emits_dismissed() -> void:
	watch_signals(_overlay)
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = KEY_SPACE
	_overlay._input(event)
	assert_signal_emitted(_overlay, "dismissed")


func test_key_echo_does_not_dismiss() -> void:
	watch_signals(_overlay)
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = true
	event.keycode = KEY_SPACE
	_overlay._input(event)
	assert_signal_not_emitted(_overlay, "dismissed")


func test_key_release_does_not_dismiss() -> void:
	watch_signals(_overlay)
	var event := InputEventKey.new()
	event.pressed = false
	event.echo = false
	event.keycode = KEY_SPACE
	_overlay._input(event)
	assert_signal_not_emitted(_overlay, "dismissed")
