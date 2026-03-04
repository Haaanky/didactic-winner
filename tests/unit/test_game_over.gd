extends GutTest

# UI tests for GameOverScreen — covers mouse click, keyboard, and touch paths.
#
# Platform coverage:
#   Desktop (Linux / Windows) — Button.pressed signal path
#   Web (GitHub Pages)        — both mouse and touch paths
#   Mobile                    — InputEventScreenTouch through _input()

const GAME_OVER_SCENE := preload("res://scenes/ui/game_over.tscn")

var _screen: GameOverScreen


func before_each() -> void:
	_screen = GAME_OVER_SCENE.instantiate() as GameOverScreen
	add_child(_screen)
	await get_tree().process_frame


func after_each() -> void:
	SceneManager._queued_scene = ""
	if is_instance_valid(_screen):
		_screen.queue_free()


# ── Node wiring ───────────────────────────────────────────────────────────────

func test_days_label_is_wired() -> void:
	assert_not_null(_screen.days_label)


func test_retry_button_is_wired() -> void:
	assert_not_null(_screen.retry_button)


# ── Days label content ────────────────────────────────────────────────────────

func test_days_label_reflects_time_manager() -> void:
	var old_days: int = TimeManager.total_days_elapsed
	TimeManager.total_days_elapsed = 2
	_screen.queue_free()
	_screen = GAME_OVER_SCENE.instantiate() as GameOverScreen
	add_child(_screen)
	await get_tree().process_frame
	assert_true(_screen.days_label.text.contains("2"))
	TimeManager.total_days_elapsed = old_days


func test_days_label_singular_for_one_day() -> void:
	var old_days: int = TimeManager.total_days_elapsed
	TimeManager.total_days_elapsed = 1
	_screen.queue_free()
	_screen = GAME_OVER_SCENE.instantiate() as GameOverScreen
	add_child(_screen)
	await get_tree().process_frame
	assert_true(_screen.days_label.text.contains("1 day."))
	TimeManager.total_days_elapsed = old_days


# ── Desktop: Button.pressed queues main menu ──────────────────────────────────

func test_retry_button_pressed_queues_main_menu() -> void:
	_screen.retry_button.pressed.emit()
	assert_eq(SceneManager._queued_scene, SceneManager.MAIN_MENU_SCENE)


# ── Mobile: touch tap on button routes through _input ─────────────────────────

func test_touch_on_retry_button_queues_main_menu() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _screen.retry_button.get_global_rect().get_center()
	_screen._input(touch)
	assert_eq(SceneManager._queued_scene, SceneManager.MAIN_MENU_SCENE)


func test_touch_release_does_not_queue_scene() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	touch.position = _screen.retry_button.get_global_rect().get_center()
	_screen._input(touch)
	assert_eq(SceneManager._queued_scene, "")


func test_touch_outside_button_does_not_queue_scene() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(-999.0, -999.0)
	_screen._input(touch)
	assert_eq(SceneManager._queued_scene, "")
