extends GutTest

# UI tests for WinScreen — covers mouse click, keyboard, and touch paths.
#
# Platform coverage:
#   Desktop (Linux / Windows) — Button.pressed signal path
#   Web (GitHub Pages)        — both mouse and touch paths
#   Mobile                    — InputEventScreenTouch through _input()

const WIN_SCREEN_SCENE := preload("res://scenes/ui/win_screen.tscn")

var _screen: WinScreen


func before_each() -> void:
	_screen = WIN_SCREEN_SCENE.instantiate() as WinScreen
	add_child(_screen)
	await get_tree().process_frame


func after_each() -> void:
	SceneManager._queued_scene = ""
	if is_instance_valid(_screen):
		_screen.queue_free()


# ── Node wiring ───────────────────────────────────────────────────────────────

func test_stats_label_is_wired() -> void:
	assert_not_null(_screen.stats_label)


func test_play_again_button_is_wired() -> void:
	assert_not_null(_screen.play_again_button)


# ── Stats label content ───────────────────────────────────────────────────────

func test_stats_label_contains_days_survived() -> void:
	var old_days: int = TimeManager.total_days_elapsed
	TimeManager.total_days_elapsed = 4
	_screen.queue_free()
	_screen = WIN_SCREEN_SCENE.instantiate() as WinScreen
	add_child(_screen)
	await get_tree().process_frame
	assert_true(_screen.stats_label.text.contains("4"))
	TimeManager.total_days_elapsed = old_days


func test_stats_label_contains_season_name() -> void:
	_screen.queue_free()
	_screen = WIN_SCREEN_SCENE.instantiate() as WinScreen
	add_child(_screen)
	await get_tree().process_frame
	var season_name: String = TimeManager.get_season_name()
	assert_true(_screen.stats_label.text.contains(season_name))


# ── Desktop: Button.pressed queues main menu ──────────────────────────────────

func test_play_again_button_pressed_queues_main_menu() -> void:
	_screen.play_again_button.pressed.emit()
	assert_eq(SceneManager._queued_scene, SceneManager.MAIN_MENU_SCENE)


# ── Mobile: touch tap on button routes through _input ─────────────────────────

func test_touch_on_play_again_queues_main_menu() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _screen.play_again_button.get_global_rect().get_center()
	_screen._input(touch)
	assert_eq(SceneManager._queued_scene, SceneManager.MAIN_MENU_SCENE)


func test_touch_release_does_not_queue_scene() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	touch.position = _screen.play_again_button.get_global_rect().get_center()
	_screen._input(touch)
	assert_eq(SceneManager._queued_scene, "")


func test_touch_outside_button_does_not_queue_scene() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(-999.0, -999.0)
	_screen._input(touch)
	assert_eq(SceneManager._queued_scene, "")
