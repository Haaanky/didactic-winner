extends GutTest

# Tests SceneManager queue behaviour in isolation.
# Uses a fresh SceneManager instance — does NOT use the autoload singleton —
# so tests remain independent of runtime order and never change the live scene.
#
# change_scene_to_file() is never reached in these tests because:
#   - invalid paths fail the ResourceLoader.exists() guard and return early
#   - valid-path tests only inspect the queue without calling _process()

var _sm: SceneManager


func before_each() -> void:
	_sm = SceneManager.new()
	add_child(_sm)


func after_each() -> void:
	_sm.queue_free()


func test_initial_queue_is_empty() -> void:
	assert_eq(_sm._queued_scene, "")


func test_go_to_level_sets_queued_scene() -> void:
	_sm.go_to_level("res://scenes/levels/level_01.tscn")
	assert_eq(_sm._queued_scene, "res://scenes/levels/level_01.tscn")


func test_go_to_level_01_queues_level_01_constant() -> void:
	_sm.go_to_level_01()
	assert_eq(_sm._queued_scene, SceneManager.LEVEL_01_SCENE)


func test_go_to_main_menu_queues_main_menu_constant() -> void:
	_sm.go_to_main_menu()
	assert_eq(_sm._queued_scene, SceneManager.MAIN_MENU_SCENE)


func test_process_does_nothing_when_queue_is_empty() -> void:
	_sm._process(0.0)
	assert_eq(_sm._queued_scene, "")


# Error path: non-existent scene — ResourceLoader.exists() returns false,
# push_error is called, queue is cleared, change_scene_to_file is never called.
func test_process_clears_queue_for_nonexistent_scene() -> void:
	_sm._queued_scene = "res://does_not_exist.tscn"
	_sm._process(0.0)
	assert_eq(_sm._queued_scene, "")


func test_process_clears_queue_after_handling_invalid_path() -> void:
	_sm.go_to_level("res://no_such_file.tscn")
	_sm._process(0.0)
	assert_eq(_sm._queued_scene, "")


func test_queuing_twice_keeps_last_path() -> void:
	_sm.go_to_level("res://first.tscn")
	_sm.go_to_level("res://second.tscn")
	assert_eq(_sm._queued_scene, "res://second.tscn")
