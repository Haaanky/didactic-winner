extends GutTest

# UI tests for PauseMenu — covers signal-driven visibility and button actions.
#
# Platform coverage:
#   Desktop (Linux / Windows) — Button.pressed signal path
#   Web (GitHub Pages)        — both mouse and touch paths
#   Mobile                    — InputEventScreenTouch through _input()

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")

var _menu: PauseMenu


func before_each() -> void:
	_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	add_child(_menu)
	await get_tree().process_frame


func after_each() -> void:
	get_tree().paused = false
	SceneManager._queued_scene = ""
	if is_instance_valid(_menu):
		_menu.queue_free()


# ── Node wiring ───────────────────────────────────────────────────────────────

func test_resume_button_is_wired() -> void:
	assert_not_null(_menu.resume_button)


func test_menu_button_is_wired() -> void:
	assert_not_null(_menu.menu_button)


# ── Initial state ─────────────────────────────────────────────────────────────

func test_pause_menu_hidden_on_start() -> void:
	assert_false(_menu.visible)


# ── game_paused signal drives visibility ──────────────────────────────────────

func test_game_paused_true_shows_menu() -> void:
	EventBus.game_paused.emit(true)
	assert_true(_menu.visible)
	get_tree().paused = false


func test_game_paused_false_hides_menu() -> void:
	EventBus.game_paused.emit(true)
	EventBus.game_paused.emit(false)
	assert_false(_menu.visible)
	get_tree().paused = false


# ── Desktop: Resume button emits game_paused(false) ──────────────────────────

func test_resume_button_emits_game_paused_false() -> void:
	EventBus.game_paused.emit(true)
	watch_signals(EventBus)
	_menu.resume_button.pressed.emit()
	assert_signal_emitted_with_parameters(EventBus, "game_paused", [false])
	get_tree().paused = false


# ── Desktop: Menu button queues main menu scene ───────────────────────────────

func test_menu_button_queues_main_menu() -> void:
	_menu.menu_button.pressed.emit()
	assert_eq(SceneManager._queued_scene, SceneManager.MAIN_MENU_SCENE)


# ── Mobile: touch on resume routes through _input ────────────────────────────

func test_touch_on_resume_when_visible_emits_game_paused_false() -> void:
	EventBus.game_paused.emit(true)
	watch_signals(EventBus)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _menu.resume_button.get_global_rect().get_center()
	_menu._input(touch)
	assert_signal_emitted_with_parameters(EventBus, "game_paused", [false])
	get_tree().paused = false


func test_touch_on_resume_when_hidden_does_nothing() -> void:
	watch_signals(EventBus)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _menu.resume_button.get_global_rect().get_center()
	_menu._input(touch)
	assert_signal_not_emitted(EventBus, "game_paused")


func test_touch_on_menu_button_when_visible_queues_main_menu() -> void:
	# Show menu directly to avoid tree-pause (game_paused.emit(true) also pauses the
	# tree, preventing layout recalculation needed for get_global_rect()).
	_menu.show()
	await get_tree().process_frame
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _menu.menu_button.get_global_rect().get_center()
	_menu._input(touch)
	assert_eq(SceneManager._queued_scene, SceneManager.MAIN_MENU_SCENE)
